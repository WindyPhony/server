# xk265 1-frame in-loop filter efficiency report

## Experiment

- Source video: `../video_test/akiyo_qcif.y4m`
- Raw input used by RTL: `reports/inloop_filter_smoke_1f/input_176x144_1f.yuv`
- Format: YUV 4:2:0, 8-bit
- Resolution: 176x144
- Frames: 1
- GOP: 1
- Mode: I/P; GOP boundary frames are Intra and all other frames are Inter
- QP: 20
- FPS: 30000/1001 (29.970030)
- Measurement: RTL testbench `RD_RESULT` and `INLOOP_FRAME_RESULT`
- Baseline: `ENABLE_DBSAO=0`
- Candidate: `ENABLE_DBSAO=1`

## Verification

- DB/SAO off: 1 `RD_RESULT` rows and 1 `INLOOP_FRAME_RESULT` rows
- DB/SAO on: 1 `RD_RESULT` rows and 1 `INLOOP_FRAME_RESULT` rows
- Both simulator logs contain `Errors: 0, Warnings: 0`
- Frame structure check passed for GOP 1
- QP consistency check passed for all encoded frames

## In-loop activity

| Run | DB modified cycles | SAO nonzero cycles | Fetch writes | Store writes | Ref-load words |
|---|---:|---:|---:|---:|---:|
| DB/SAO off | 0 | 0 | 3996 | 3648 | 0 |
| DB/SAO on | 5842 | 6655 | 3996 | 3648 | 0 |

## Summary

| Case | Total bits | Bitrate kbps | Avg frame PSNR | Sequence PSNR from avg MSE | Avg MSE | Bit delta vs off | Bitrate delta | Avg PSNR delta |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| DB/SAO off | 33968 | 1018.022 | 44.455689 | 44.455690 | 2.330834 | 0.000% | 0.000 | 0.000000 |
| DB/SAO on | 33968 | 1018.022 | 29.440994 | 29.440994 | 73.957281 | 0.000% | 0.000 | -15.014695 |

## Per-frame CSV

- `reports/inloop_filter_smoke_1f/inloop_filter_frames.csv`

## Conclusion

Enabling DB/SAO changed total bits by 0 bits (0.000%) and bitrate by 0.000 kbps.
Average frame PSNR changed by -15.014695 dB; sequence PSNR from average MSE changed by -15.014696 dB.
