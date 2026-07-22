# xk265 100-frame in-loop filter efficiency report

## Experiment

- Source video: `/home/userdata/k69D/phongpx_69d/projects/xk265/video_test/akiyo_qcif.y4m`
- Raw input used by RTL: `/home/userdata/k69D/phongpx_69d/projects/xk265/xk265/reports/inloop_filter_100f/input_176x144_100f.yuv`
- Format: YUV 4:2:0, 8-bit
- Resolution: 176x144
- Frames: 100
- GOP: 100
- Mode: I/P; GOP boundary frames are Intra and all other frames are Inter
- QP: 20
- FPS: 30000/1001 (29.970030)
- Measurement: RTL testbench `RD_RESULT` and `INLOOP_FRAME_RESULT`
- Baseline: `ENABLE_DBSAO=0`
- Candidate: `ENABLE_DBSAO=1`

## Verification

- DB/SAO off: 100 `RD_RESULT` rows and 100 `INLOOP_FRAME_RESULT` rows
- DB/SAO on: 100 `RD_RESULT` rows and 100 `INLOOP_FRAME_RESULT` rows
- Both simulator logs contain `Errors: 0, Warnings: 0`
- Frame structure check passed for GOP 100
- QP consistency check passed for all encoded frames

## In-loop activity

| Run | DB modified cycles | SAO nonzero cycles | Fetch writes | Store writes | Ref-load words |
|---|---:|---:|---:|---:|---:|
| DB/SAO off | 0 | 0 | 399600 | 364800 | 760320 |
| DB/SAO on | 62376 | 698537 | 399600 | 364800 | 760320 |

## Summary

| Case | Total bits | Bitrate kbps | Avg frame PSNR | Sequence PSNR from avg MSE | Avg MSE | Bit delta vs off | Bitrate delta | Avg PSNR delta |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| DB/SAO off | 1112712 | 333.480 | 43.466107 | 43.460374 | 2.931183 | 0.000% | 0.000 | 0.000000 |
| DB/SAO on | 1355320 | 406.190 | 30.495003 | 30.491072 | 58.072851 | 21.803% | 72.710 | -12.971104 |

## Per-frame CSV

- `/home/userdata/k69D/phongpx_69d/projects/xk265/xk265/reports/inloop_filter_100f/inloop_filter_frames.csv`

## Conclusion

Enabling DB/SAO changed total bits by 242608 bits (21.803%) and bitrate by 72.710 kbps.
Average frame PSNR changed by -12.971104 dB; sequence PSNR from average MSE changed by -12.969302 dB.
