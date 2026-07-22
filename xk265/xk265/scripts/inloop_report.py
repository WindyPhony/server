#!/usr/bin/env python3
"""Prepare YUV input and report xk265 in-loop filter simulation metrics."""

import argparse
import csv
import math
import re
from pathlib import Path
from typing import Dict, List, Tuple


RD_RE = re.compile(
    r"RD_RESULT frame=(?P<frame>\d+) qp=(?P<qp>\d+) dbsao=(?P<dbsao>\d+) "
    r"bits=(?P<bits>\d+) psnr=(?P<psnr>[0-9.]+) mse=(?P<mse>[0-9.]+)"
)

IL_RE = re.compile(r"INLOOP_FRAME_RESULT (?P<body>.*)")


class RdRow:
    __slots__ = ("frame", "qp", "dbsao", "bits", "psnr", "mse")

    def __init__(self, frame, qp, dbsao, bits, psnr, mse):
        self.frame = frame
        self.qp = qp
        self.dbsao = dbsao
        self.bits = bits
        self.psnr = psnr
        self.mse = mse


def parse_int(value: str) -> int:
    return int(value, 10)


def parse_y4m_or_raw(data: bytes, frame_bytes: int, frames: int) -> bytes:
    pos = 0
    if data.startswith(b"YUV4MPEG2"):
        header_end = data.find(b"\n")
        if header_end < 0:
            raise ValueError("Y4M header has no newline")
        pos = header_end + 1

    if data[pos : pos + 5] == b"FRAME":
        out = bytearray()
        for frame in range(frames):
            if data[pos : pos + 5] != b"FRAME":
                raise ValueError(f"missing FRAME marker before frame {frame}")
            line_end = data.find(b"\n", pos)
            if line_end < 0:
                raise ValueError(f"FRAME marker before frame {frame} has no newline")
            pos = line_end + 1
            frame_end = pos + frame_bytes
            if frame_end > len(data):
                raise ValueError(f"not enough payload bytes for frame {frame}")
            out.extend(data[pos:frame_end])
            pos = frame_end
        return bytes(out)

    needed = frame_bytes * frames
    if len(data) - pos < needed:
        raise ValueError(
            f"raw input is too small: need {needed} bytes, found {len(data) - pos}"
        )
    return data[pos : pos + needed]


def prepare_yuv(args: argparse.Namespace) -> None:
    frame_bytes = args.width * args.height * 3 // 2
    expected_bytes = frame_bytes * args.frames
    data = Path(args.input).read_bytes()
    raw = parse_y4m_or_raw(data, frame_bytes, args.frames)
    if len(raw) != expected_bytes:
        raise RuntimeError(f"internal size error: got {len(raw)}, expected {expected_bytes}")

    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)
    tmp = output.with_suffix(output.suffix + ".tmp")
    tmp.write_bytes(raw)
    tmp.replace(output)
    print(
        f"Prepared {output} from {args.input}: "
        f"{args.width}x{args.height}, {args.frames} frames, {expected_bytes} bytes"
    )


def parse_key_values(body: str) -> Dict[str, int]:
    values = {}  # type: Dict[str, int]
    for token in body.split():
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        values[key] = parse_int(value)
    return values


def parse_log(path: Path, expected_dbsao: int) -> Tuple[List[RdRow], List[Dict[str, int]]]:
    text = path.read_text(errors="replace")
    if "Errors: 0, Warnings: 0" not in text:
        raise ValueError(f"{path} does not contain a clean simulator summary")

    rd_rows = []  # type: List[RdRow]
    il_rows = []  # type: List[Dict[str, int]]
    for line in text.splitlines():
        rd_match = RD_RE.search(line)
        if rd_match:
            row = RdRow(
                frame=parse_int(rd_match.group("frame")),
                qp=parse_int(rd_match.group("qp")),
                dbsao=parse_int(rd_match.group("dbsao")),
                bits=parse_int(rd_match.group("bits")),
                psnr=float(rd_match.group("psnr")),
                mse=float(rd_match.group("mse")),
            )
            rd_rows.append(row)
            continue

        il_match = IL_RE.search(line)
        if il_match:
            il_rows.append(parse_key_values(il_match.group("body")))

    for row in rd_rows:
        if row.dbsao != expected_dbsao:
            raise ValueError(f"{path}: frame {row.frame} has dbsao={row.dbsao}")
    for row in il_rows:
        if row.get("dbsao") != expected_dbsao:
            raise ValueError(f"{path}: frame {row.get('frame')} has dbsao={row.get('dbsao')}")
    return rd_rows, il_rows


def validate_rows(
    label: str,
    rd_rows: List[RdRow],
    il_rows: List[Dict[str, int]],
    frames: int,
    gop: int,
    qp: int,
) -> None:
    if len(rd_rows) != frames:
        raise ValueError(f"{label}: expected {frames} RD_RESULT rows, found {len(rd_rows)}")
    if len(il_rows) != frames:
        raise ValueError(
            f"{label}: expected {frames} INLOOP_FRAME_RESULT rows, found {len(il_rows)}"
        )

    rd_frames = [row.frame for row in rd_rows]
    il_frames = [row.get("frame") for row in il_rows]
    expected_frames = list(range(frames))
    if rd_frames != expected_frames:
        raise ValueError(f"{label}: RD frame sequence mismatch")
    if il_frames != expected_frames:
        raise ValueError(f"{label}: INLOOP frame sequence mismatch")

    bad_qp = [row.frame for row in rd_rows if row.qp != qp]
    if bad_qp:
        raise ValueError(f"{label}: QP mismatch at frames {bad_qp[:8]}")

    for row in il_rows:
        expected_type = 0 if row["frame"] % gop == 0 else 1
        if row.get("type") != expected_type:
            raise ValueError(
                f"{label}: frame {row['frame']} type={row.get('type')}, expected {expected_type}"
            )


def summarize(rd_rows: List[RdRow], il_rows: List[Dict[str, int]], fps: float) -> Dict[str, float]:
    frames = len(rd_rows)
    total_bits = sum(row.bits for row in rd_rows)
    avg_psnr = sum(row.psnr for row in rd_rows) / frames
    avg_mse = sum(row.mse for row in rd_rows) / frames
    seq_psnr = 99.999 if avg_mse == 0 else 10.0 * math.log10((255.0 * 255.0) / avg_mse)
    bitrate_kbps = total_bits * fps / frames / 1000.0
    summary = {
        "frames": frames,
        "total_bits": total_bits,
        "avg_psnr": avg_psnr,
        "avg_mse": avg_mse,
        "seq_psnr": seq_psnr,
        "bitrate_kbps": bitrate_kbps,
    }
    for key in (
        "db_modified_cycles",
        "sao_nonzero_cycles",
        "fetch_writes",
        "store_writes",
        "load_ref_words",
        "ime_ref_reads",
        "fme_ref_reads",
        "mc_ref_reads",
    ):
        summary[key] = sum(row.get(key, 0) for row in il_rows)
    return summary


def pct_delta(new: float, base: float) -> float:
    if base == 0:
        return 0.0
    return 100.0 * (new - base) / base


def type_name(type_id: int) -> str:
    return "I" if type_id == 0 else "P"


def write_csv(path: Path, off_rows: List[RdRow], on_rows: List[RdRow], gop: int) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(
            [
                "frame",
                "type",
                "off_bits",
                "on_bits",
                "bit_delta",
                "bit_delta_pct",
                "off_psnr",
                "on_psnr",
                "psnr_delta",
                "off_mse",
                "on_mse",
                "mse_delta",
            ]
        )
        for off, on in zip(off_rows, on_rows):
            writer.writerow(
                [
                    off.frame,
                    type_name(0 if off.frame % gop == 0 else 1),
                    off.bits,
                    on.bits,
                    on.bits - off.bits,
                    f"{pct_delta(on.bits, off.bits):.6f}",
                    f"{off.psnr:.6f}",
                    f"{on.psnr:.6f}",
                    f"{on.psnr - off.psnr:.6f}",
                    f"{off.mse:.6f}",
                    f"{on.mse:.6f}",
                    f"{on.mse - off.mse:.6f}",
                ]
            )


def write_report(
    path: Path,
    args: argparse.Namespace,
    off_rows: List[RdRow],
    on_rows: List[RdRow],
    off_il: List[Dict[str, int]],
    on_il: List[Dict[str, int]],
    csv_path: Path,
) -> None:
    fps = args.fps_num / args.fps_den
    off = summarize(off_rows, off_il, fps)
    on = summarize(on_rows, on_il, fps)
    bit_delta = on["total_bits"] - off["total_bits"]
    bit_delta_pct = pct_delta(on["total_bits"], off["total_bits"])
    bitrate_delta = on["bitrate_kbps"] - off["bitrate_kbps"]
    psnr_delta = on["avg_psnr"] - off["avg_psnr"]
    seq_psnr_delta = on["seq_psnr"] - off["seq_psnr"]

    lines = [
        f"# xk265 {args.frames}-frame in-loop filter efficiency report",
        "",
        "## Experiment",
        "",
        f"- Source video: `{args.video}`",
        f"- Raw input used by RTL: `{args.raw_yuv}`",
        "- Format: YUV 4:2:0, 8-bit",
        f"- Resolution: {args.width}x{args.height}",
        f"- Frames: {args.frames}",
        f"- GOP: {args.gop}",
        "- Mode: I/P; GOP boundary frames are Intra and all other frames are Inter",
        f"- QP: {args.qp}",
        f"- FPS: {args.fps_num}/{args.fps_den} ({fps:.6f})",
        "- Measurement: RTL testbench `RD_RESULT` and `INLOOP_FRAME_RESULT`",
        "- Baseline: `ENABLE_DBSAO=0`",
        "- Candidate: `ENABLE_DBSAO=1`",
        "",
        "## Verification",
        "",
        f"- DB/SAO off: {args.frames} `RD_RESULT` rows and {args.frames} `INLOOP_FRAME_RESULT` rows",
        f"- DB/SAO on: {args.frames} `RD_RESULT` rows and {args.frames} `INLOOP_FRAME_RESULT` rows",
        "- Both simulator logs contain `Errors: 0, Warnings: 0`",
        f"- Frame structure check passed for GOP {args.gop}",
        "- QP consistency check passed for all encoded frames",
        "",
        "## In-loop activity",
        "",
        "| Run | DB modified cycles | SAO nonzero cycles | Fetch writes | Store writes | Ref-load words |",
        "|---|---:|---:|---:|---:|---:|",
        (
            f"| DB/SAO off | {off['db_modified_cycles']:.0f} | {off['sao_nonzero_cycles']:.0f} | "
            f"{off['fetch_writes']:.0f} | {off['store_writes']:.0f} | {off['load_ref_words']:.0f} |"
        ),
        (
            f"| DB/SAO on | {on['db_modified_cycles']:.0f} | {on['sao_nonzero_cycles']:.0f} | "
            f"{on['fetch_writes']:.0f} | {on['store_writes']:.0f} | {on['load_ref_words']:.0f} |"
        ),
        "",
        "## Summary",
        "",
        (
            "| Case | Total bits | Bitrate kbps | Avg frame PSNR | Sequence PSNR from avg MSE | "
            "Avg MSE | Bit delta vs off | Bitrate delta | Avg PSNR delta |"
        ),
        "|---|---:|---:|---:|---:|---:|---:|---:|---:|",
        (
            f"| DB/SAO off | {off['total_bits']:.0f} | {off['bitrate_kbps']:.3f} | "
            f"{off['avg_psnr']:.6f} | {off['seq_psnr']:.6f} | {off['avg_mse']:.6f} | "
            "0.000% | 0.000 | 0.000000 |"
        ),
        (
            f"| DB/SAO on | {on['total_bits']:.0f} | {on['bitrate_kbps']:.3f} | "
            f"{on['avg_psnr']:.6f} | {on['seq_psnr']:.6f} | {on['avg_mse']:.6f} | "
            f"{bit_delta_pct:.3f}% | {bitrate_delta:.3f} | {psnr_delta:.6f} |"
        ),
        "",
        "## Per-frame CSV",
        "",
        f"- `{csv_path}`",
        "",
        "## Conclusion",
        "",
        (
            f"Enabling DB/SAO changed total bits by {bit_delta:.0f} bits "
            f"({bit_delta_pct:.3f}%) and bitrate by {bitrate_delta:.3f} kbps."
        ),
        (
            f"Average frame PSNR changed by {psnr_delta:.6f} dB; sequence PSNR from "
            f"average MSE changed by {seq_psnr_delta:.6f} dB."
        ),
    ]

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines) + "\n")


def report(args: argparse.Namespace) -> None:
    off_rows, off_il = parse_log(Path(args.off_log), expected_dbsao=0)
    on_rows, on_il = parse_log(Path(args.on_log), expected_dbsao=1)
    validate_rows("DB/SAO off", off_rows, off_il, args.frames, args.gop, args.qp)
    validate_rows("DB/SAO on", on_rows, on_il, args.frames, args.gop, args.qp)

    csv_path = Path(args.csv)
    report_path = Path(args.report)
    write_csv(csv_path, off_rows, on_rows, args.gop)
    write_report(report_path, args, off_rows, on_rows, off_il, on_il, csv_path)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="cmd")
    subparsers.required = True

    prepare = subparsers.add_parser("prepare-yuv")
    prepare.add_argument("--input", required=True)
    prepare.add_argument("--output", required=True)
    prepare.add_argument("--width", type=int, required=True)
    prepare.add_argument("--height", type=int, required=True)
    prepare.add_argument("--frames", type=int, required=True)
    prepare.set_defaults(func=prepare_yuv)

    rep = subparsers.add_parser("report")
    rep.add_argument("--off-log", required=True)
    rep.add_argument("--on-log", required=True)
    rep.add_argument("--report", required=True)
    rep.add_argument("--csv", required=True)
    rep.add_argument("--video", required=True)
    rep.add_argument("--raw-yuv", required=True)
    rep.add_argument("--width", type=int, required=True)
    rep.add_argument("--height", type=int, required=True)
    rep.add_argument("--frames", type=int, required=True)
    rep.add_argument("--gop", type=int, required=True)
    rep.add_argument("--qp", type=int, required=True)
    rep.add_argument("--fps-num", type=int, required=True)
    rep.add_argument("--fps-den", type=int, required=True)
    rep.set_defaults(func=report)
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
