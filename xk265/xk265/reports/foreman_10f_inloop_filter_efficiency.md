# Foreman 416x240 10-frame I/P in-loop filter efficiency report

## Experiment

- Sequence: `sim/top_testbench/tv/foreman_10frames_416x240.yuv`
- Format: YUV 4:2:0, 8-bit
- Resolution: 416x240
- Frames: 10
- GOP: 10
- Mode: I/P; frame 0 encoded as Intra, frames 1-9 encoded as Inter
- QP: 20
- Simulator: QuestaSim-64 2024.2
- Measurement: RTL testbench `RD_RESULT` and `INLOOP_FRAME_RESULT`

Input size was confirmed:

```text
416 * 240 * 3 / 2 * 10 = 1,497,600 bytes
```

## Run setup

Both runs were compiled from `sim/top_testbench/` with the same settings except `ENABLE_DBSAO`.

Common compile defines:

```text
+define+FRAME_WIDTH=416
+define+FRAME_HEIGHT=240
+define+FRAME_TOTAL=10
+define+GOP_LENGTH=10
+define+TEST_I=1
+define+TEST_P=1
+define+FILE_CUR_YUV="./tv/foreman_10frames_416x240.yuv"
+define+SMOKE_NO_GOLDEN
+define+NO_DUMP
+define+RD_MONITOR
+define+INLOOP_TRACE
```

Baseline:

```text
+define+ENABLE_DBSAO=0
```

Candidate:

```text
+define+ENABLE_DBSAO=1
```

The golden bitstream/REC checks were disabled with `SMOKE_NO_GOLDEN` because the repository golden files are for a different 2-frame reference. Verification used successful RTL completion plus monitor output.

## Verification result

Both simulations completed successfully:

```text
Errors: 0, Warnings: 0
```

Frame-start messages confirmed the requested coding structure:

```text
frame 0: INTRA
frames 1-9: INTER
```

Monitor counts:

| Run | RD_RESULT lines | INLOOP_FRAME_RESULT lines | Encoded frames |
|---|---:|---:|---:|
| DBSAO off | 10 | 10 | 10 |
| DBSAO on | 10 | 10 | 10 |

In-loop activity summary:

| Run | DB modified cycles | SAO nonzero cycles | Fetch writes | Store writes | Ref-load words |
|---|---:|---:|---:|---:|---:|
| DBSAO off | 0 | 0 | 127200 | 114240 | 200448 |
| DBSAO on | 37263 | 215147 | 127200 | 114240 | 200448 |

The enabled run therefore exercised the DB/SAO path.

## Per-frame RD results

| Frame | Type | Off bits | Off PSNR | On bits | On PSNR | Bit delta | PSNR delta |
|---:|---|---:|---:|---:|---:|---:|---:|
| 0 | I | 118808 | 44.311615 | 118808 | 42.898711 | 0 | -1.412904 |
| 1 | P | 66424 | 43.074060 | 67080 | 42.821972 | 656 | -0.252088 |
| 2 | P | 72088 | 42.955236 | 69872 | 42.748219 | -2216 | -0.207017 |
| 3 | P | 65072 | 42.898155 | 64344 | 42.742127 | -728 | -0.156028 |
| 4 | P | 73112 | 42.805774 | 71688 | 42.819573 | -1424 | 0.013799 |
| 5 | P | 71464 | 42.737241 | 69072 | 42.834434 | -2392 | 0.097193 |
| 6 | P | 61808 | 42.809035 | 59520 | 42.837193 | -2288 | 0.028158 |
| 7 | P | 74056 | 42.676028 | 72664 | 42.791672 | -1392 | 0.115644 |
| 8 | P | 77552 | 42.604708 | 75688 | 42.786112 | -1864 | 0.181404 |
| 9 | P | 79832 | 42.579467 | 75456 | 42.782708 | -4376 | 0.203241 |

## Efficiency summary

| Case | Frames | GOP | QP | Filter | Total bits | Avg PSNR | Avg MSE | Bit delta vs off | PSNR delta vs off |
|---|---:|---:|---:|---|---:|---:|---:|---:|---:|
| Baseline | 10 | 10 | 20 | DB/SAO off | 760216 | 42.945132 | 3.318930 | 0.000% | 0.000000 dB |
| Candidate | 10 | 10 | 20 | DB/SAO on | 744192 | 42.806272 | 3.407810 | -2.108% | -0.138860 dB |

Formulas:

```text
bit_delta_pct = 100 * (bits_on - bits_off) / bits_off
psnr_delta_db = avg_psnr_on - avg_psnr_off
```

## Conclusion

For this 10-frame Foreman 416x240 I/P encode at QP 20, enabling DB/SAO reduced total coded bits by 16,024 bits, or 2.108%, but reduced average PSNR by 0.138860 dB.

The later P frames benefit from filtering in both bitrate and PSNR, but the Intra frame loses 1.412904 dB PSNR with no bitrate change. Over the full 10-frame sequence, the RTL in-loop filter is bitrate-efficient but not PSNR-efficient at this fixed-QP operating point.
