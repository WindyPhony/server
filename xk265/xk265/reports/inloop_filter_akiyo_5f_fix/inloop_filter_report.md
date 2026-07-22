# xk265 5-frame in-loop filter efficiency report

## Experiment

- Source video: `/home/userdata/k69D/phongpx_69d/projects/xk265/video_test/akiyo_qcif.y4m`
- Raw input used by RTL: `/home/userdata/k69D/phongpx_69d/projects/xk265/xk265/reports/inloop_filter_akiyo_5f_fix/input_176x144_5f.yuv`
- Format: YUV 4:2:0, 8-bit
- Resolution: 176x144
- Frames: 5
- GOP: 5
- Mode: I/P; GOP boundary frames are Intra and all other frames are Inter
- QP: 20
- FPS: 30000/1001 (29.970030)
- Measurement: RTL testbench `RD_RESULT` and `INLOOP_FRAME_RESULT`
- Baseline: `ENABLE_DBSAO=0`
- Candidate: `ENABLE_DBSAO=1`

## Verification

- DB/SAO off: 5 `RD_RESULT` rows and 5 `INLOOP_FRAME_RESULT` rows
- DB/SAO on: 5 `RD_RESULT` rows and 5 `INLOOP_FRAME_RESULT` rows
- Both simulator logs contain `Errors: 0, Warnings: 0`
- Frame structure check passed for GOP 5
- QP consistency check passed for all encoded frames

## In-loop activity

| Run | DB modified cycles | SAO nonzero cycles | Fetch writes | Store writes | Ref-load words |
|---|---:|---:|---:|---:|---:|
| DB/SAO off | 0 | 0 | 19980 | 18240 | 30720 |
| DB/SAO on | 8233 | 34771 | 19980 | 18240 | 30720 |

## Summary

| Case | Total bits | Bitrate kbps | Avg frame PSNR | Sequence PSNR from avg MSE | Avg MSE | Bit delta vs off | Bitrate delta | Avg PSNR delta |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| DB/SAO off | 69016 | 413.682 | 44.066436 | 44.061909 | 2.552052 | 0.000% | 0.000 | 0.000000 |
| DB/SAO on | 85104 | 510.114 | 30.310622 | 30.285430 | 60.888789 | 23.311% | 96.432 | -13.755814 |

## Per-frame CSV

- `/home/userdata/k69D/phongpx_69d/projects/xk265/xk265/reports/inloop_filter_akiyo_5f_fix/inloop_filter_frames.csv`

## Conclusion

Enabling DB/SAO changed total bits by 16088 bits (23.311%) and bitrate by 96.432 kbps.
Average frame PSNR changed by -13.755814 dB; sequence PSNR from average MSE changed by -13.776478 dB.
