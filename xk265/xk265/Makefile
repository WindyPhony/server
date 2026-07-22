SHELL := /bin/bash
.DEFAULT_GOAL := help
.NOTPARALLEL:

TB_DIR := sim/top_testbench
REPORT_TOOL := scripts/inloop_report.py

VIDEO_SRC ?= ../video_test/akiyo_qcif.y4m
WIDTH ?= 176
HEIGHT ?= 144
FRAMES ?= 300
GOP ?= $(FRAMES)
QP ?= 20
FPS_NUM ?= 30000
FPS_DEN ?= 1001
OUT_DIR ?= reports/inloop_filter

OUT_ABS := $(abspath $(OUT_DIR))
VIDEO_ABS := $(abspath $(VIDEO_SRC))
RAW_YUV := $(OUT_ABS)/input_$(WIDTH)x$(HEIGHT)_$(FRAMES)f.yuv
LOG_OFF := $(OUT_ABS)/dbsao_off.log
LOG_ON := $(OUT_ABS)/dbsao_on.log
COMPILE_LOG_OFF := $(OUT_ABS)/dbsao_off.compile.log
COMPILE_LOG_ON := $(OUT_ABS)/dbsao_on.compile.log
REPORT_MD := $(OUT_ABS)/inloop_filter_report.md
REPORT_CSV := $(OUT_ABS)/inloop_filter_frames.csv

COMMON_DEFINES := \
	+define+FRAME_WIDTH=$(WIDTH) \
	+define+FRAME_HEIGHT=$(HEIGHT) \
	+define+FRAME_TOTAL=$(FRAMES) \
	+define+GOP_LENGTH=$(GOP) \
	+define+INITIAL_QP=$(QP) \
	+define+TEST_I=1 \
	+define+TEST_P=1 \
	+define+FILE_CUR_YUV=\"$(RAW_YUV)\" \
	+define+SMOKE_NO_GOLDEN \
	+define+NO_DUMP \
	+define+RD_MONITOR \
	+define+INLOOP_TRACE

.PHONY: help check-tools prepare-yuv run-inloop-off run-inloop-on inloop-report clean-inloop-report

help:
	@printf '%s\n' \
		'Targets:' \
		'  make inloop-report       prepare YUV, run DB/SAO off/on RTL sims, write report' \
		'  make prepare-yuv         convert the selected source video to raw YUV420 frames' \
		'  make run-inloop-off      run RTL sim with ENABLE_DBSAO=0' \
		'  make run-inloop-on       run RTL sim with ENABLE_DBSAO=1' \
		'  make check-tools         verify python3, vlog, and vsim are available' \
		'  make clean-inloop-report remove generated logs, raw YUV, report, and sim work dir' \
		'' \
		'Common overrides:' \
		'  VIDEO_SRC=../video_test/akiyo_qcif.y4m WIDTH=176 HEIGHT=144 FRAMES=300 GOP=300 QP=20' \
		'  OUT_DIR=reports/inloop_filter FPS_NUM=30000 FPS_DEN=1001' \
		'' \
		'Prerequisite before simulation if tools are not in PATH:' \
		'  module load questasim/2024.2'

check-tools:
	@command -v python3 >/dev/null || { echo 'ERROR: python3 not found in PATH.'; exit 1; }
	@command -v vlog >/dev/null || { echo 'ERROR: vlog not found. Run: module load questasim/2024.2'; exit 1; }
	@command -v vsim >/dev/null || { echo 'ERROR: vsim not found. Run: module load questasim/2024.2'; exit 1; }

prepare-yuv:
	@mkdir -p "$(OUT_ABS)"
	@python3 "$(REPORT_TOOL)" prepare-yuv \
		--input "$(VIDEO_ABS)" \
		--output "$(RAW_YUV)" \
		--width "$(WIDTH)" \
		--height "$(HEIGHT)" \
		--frames "$(FRAMES)"

run-inloop-off: check-tools prepare-yuv
	@mkdir -p "$(OUT_ABS)"
	@echo "Running RTL simulation with ENABLE_DBSAO=0"
	@cd "$(TB_DIR)" && \
		rm -rf work transcript vsim.wlf && \
		vlib ./work >/dev/null && \
		vlog -sv +libext+.v -incr -work ./work $(COMMON_DEFINES) +define+ENABLE_DBSAO=0 -f ./file_list.f -l "$(COMPILE_LOG_OFF)" && \
		vsim -c -l "$(LOG_OFF)" +nospecify work.tb_enc_top -do "run -all; quit -f"
	@rm -rf "$(TB_DIR)/work" "$(TB_DIR)/transcript" "$(TB_DIR)/vsim.wlf"

run-inloop-on: check-tools prepare-yuv
	@mkdir -p "$(OUT_ABS)"
	@echo "Running RTL simulation with ENABLE_DBSAO=1"
	@cd "$(TB_DIR)" && \
		rm -rf work transcript vsim.wlf && \
		vlib ./work >/dev/null && \
		vlog -sv +libext+.v -incr -work ./work $(COMMON_DEFINES) +define+ENABLE_DBSAO=1 -f ./file_list.f -l "$(COMPILE_LOG_ON)" && \
		vsim -c -l "$(LOG_ON)" +nospecify work.tb_enc_top -do "run -all; quit -f"
	@rm -rf "$(TB_DIR)/work" "$(TB_DIR)/transcript" "$(TB_DIR)/vsim.wlf"

inloop-report: run-inloop-off run-inloop-on
	@python3 "$(REPORT_TOOL)" report \
		--off-log "$(LOG_OFF)" \
		--on-log "$(LOG_ON)" \
		--report "$(REPORT_MD)" \
		--csv "$(REPORT_CSV)" \
		--video "$(VIDEO_ABS)" \
		--raw-yuv "$(RAW_YUV)" \
		--width "$(WIDTH)" \
		--height "$(HEIGHT)" \
		--frames "$(FRAMES)" \
		--gop "$(GOP)" \
		--qp "$(QP)" \
		--fps-num "$(FPS_NUM)" \
		--fps-den "$(FPS_DEN)"
	@echo "Wrote $(REPORT_MD)"
	@echo "Wrote $(REPORT_CSV)"

clean-inloop-report:
	@if [ -z "$(OUT_ABS)" ] || [ "$(OUT_ABS)" = "/" ]; then \
		echo 'ERROR: refusing to remove unsafe OUT_DIR.'; \
		exit 1; \
	fi
	@rm -rf "$(OUT_ABS)" "$(TB_DIR)/work" "$(TB_DIR)/transcript" "$(TB_DIR)/vsim.wlf" "$(TB_DIR)"/etch*
