# xk265 2-frame in-loop filter efficiency report

## Experiment

- Source video: `/home/userdata/k69D/phongpx_69d/projects/xk265/video_test/akiyo_qcif.y4m`
- Raw input used by RTL: `/home/userdata/k69D/phongpx_69d/projects/xk265/xk265/reports/inloop_filter_akiyo_2f_fix/input_176x144_2f.yuv`
- Format: YUV 4:2:0, 8-bit
- Resolution: 176x144
- Frames: 2
- GOP: 2
- Mode: I/P; GOP boundary frames are Intra and all other frames are Inter
- QP: 20
- FPS: 30000/1001 (29.970030)
- Measurement: RTL testbench `RD_RESULT` and `INLOOP_FRAME_RESULT`
- Baseline: `ENABLE_DBSAO=0`
- Candidate: `ENABLE_DBSAO=1`

## Verification

- DB/SAO off: 2 `RD_RESULT` rows and 2 `INLOOP_FRAME_RESULT` rows
- DB/SAO on: 2 `RD_RESULT` rows and 2 `INLOOP_FRAME_RESULT` rows
- Both simulator logs contain `Errors: 0, Warnings: 0`
- Frame structure check passed for GOP 2
- QP consistency check passed for all encoded frames

## In-loop activity

| Run | DB modified cycles | SAO nonzero cycles | Fetch writes | Store writes | Ref-load words |
|---|---:|---:|---:|---:|---:|
| DB/SAO off | 0 | 0 | 7992 | 7296 | 7680 |
| DB/SAO on | 6452 | 13680 | 7992 | 7296 | 7680 |

## Summary

| Case | Total bits | Bitrate kbps | Avg frame PSNR | Sequence PSNR from avg MSE | Avg MSE | Bit delta vs off | Bitrate delta | Avg PSNR delta |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| DB/SAO off | 42888 | 642.677 | 44.204814 | 44.197573 | 2.473564 | 0.000% | 0.000 | 0.000000 |
| DB/SAO on | 48408 | 725.395 | 30.035041 | 29.994539 | 65.106810 | 12.871% | 82.717 | -14.169773 |

## Per-frame CSV

- `/home/userdata/k69D/phongpx_69d/projects/xk265/xk265/reports/inloop_filter_akiyo_2f_fix/inloop_filter_frames.csv`

## Conclusion

Enabling DB/SAO changed total bits by 5520 bits (12.871%) and bitrate by 82.717 kbps.
Average frame PSNR changed by -14.169773 dB; sequence PSNR from average MSE changed by -14.203034 dB.
