//---------------------------------------------------------
//
//  File Name     : tb_enc_top.v 
//  Author        : TANG  
//  Date          : 2018-05-24
//  Description   : test bench of enc_top
//
//-----------------------------------------------------------

`include "enc_defines.v"

//---- defines --------------------------------------------
  
  `define TB_NAME   tb_enc_top   

  `ifndef TEST_I
    `define TEST_I 1
  `endif
  `ifndef TEST_P
    `define TEST_P 0
  `endif

  // `define FORMAT_NV12

  `define FORMAT_YUV

  `ifndef FRAME_WIDTH
    `define FRAME_WIDTH   416 // (`FRAME_W/`LCU_SIZE + 1)*`LCU_SIZE  // full LCU
  `endif
  `ifndef FRAME_HEIGHT
    `define FRAME_HEIGHT  240 // (`FRAME_H/`LCU_SIZE + 1)*`LCU_SIZE  // full LCU
  `endif

  `ifndef INITIAL_QP
    `define INITIAL_QP    20
  `endif
  `ifndef GOP_LENGTH
    `define GOP_LENGTH    50
  `endif
  `ifndef FRAME_TOTAL
    `define FRAME_TOTAL   2
  `endif
  `ifndef ENABLE_IinP
    `define ENABLE_IinP   0
  `endif
  `ifndef ENABLE_DBSAO
    `define ENABLE_DBSAO  0
  `endif
  `ifndef USE_HW_DPB
    `define USE_HW_DPB    1
  `endif
  `ifndef POSI4x4BIT
    `define POSI4x4BIT    4 
  `endif

  `define SKIP_COST_THRESH_8  0
  `define SKIP_COST_THRESH_16 (`SKIP_COST_THRESH_8 * 7) / 2
  `define SKIP_COST_THRESH_32 (`SKIP_COST_THRESH_16 * 7) / 2
  `define SKIP_COST_THRESH_64 (`SKIP_COST_THRESH_32 * 7) / 2

  
  //`define CHECK_ONE_FRAME 1
    `define CHECK_FRAME_NUM 2 


//---- test vectors ---------------------------------------
  `ifdef FORMAT_YUV
    `ifndef FILE_CUR_YUV
      `ifdef SMOKE_NO_GOLDEN
        `define FILE_CUR_YUV    "./tv/rec.yuv"
      `else
        `define FILE_CUR_YUV    "./tv/BlowingBubbles.yuv"
      `endif
    `endif
    `define FILE_REC_YUV        "./tv/rec.yuv"
  `else 
    `ifndef FILE_CUR_YUV
      `define FILE_CUR_YUV      "./tv/BlowingBubbles_nv12.yuv"
    `endif
    `define FILE_REC_YUV        "./tv/rec_nv12.yuv"
  `endif 

  `define FILE_REG_K          "./tv/rc_coefficient.txt"
  `define FILE_FRAME_QP       "./tv/rc_frameqp.txt"

  `define FILE_CHECK_BS       "./tv/s_bit_stream.dat"

  // ime 
  `define FILE_IME_CFG        "./tv/ime_cfg.dat"

  // check list
  `ifndef SMOKE_NO_GOLDEN
    `define AUTO_CHECK
      `define CHECK_BS 
      `define CHECK_REC 
  `endif
  
  // clk 
  `define HALF_CLK           5
  `define FULL_CLK           (`HALF_CLK*2)

  // waveform
  `ifndef NO_DUMP
    `define DUMP_FSDB 
            `define DUMP_TIME    0 
            `define DUMP_FILE    "tb_top.fsdb"
  `endif
  
  // `define DUMP_SHM
  //         `define DUMP_SHM_FILE     "./dump/wave_form.shm"
  //         `define DUMP_SHM_TIME     0
  //         `define DUMP_SHM_LEVEL    "AS"    // all signal



module `TB_NAME ;

//---- parameter declaration -------------------------------------

  // global
  parameter     CMD_NUM_WIDTH          = 3                  ;

  // local
  parameter     SLOPE_1d2              = 0                  ;
  parameter     SLOPE_1                = 1                  ;
  parameter     SLOPE_2                = 2                  ;
  parameter     SLOPE_INF              = 3                  ;

  // derived
  localparam    CMD_DAT_WIDTH_ONE      =(`IME_MV_WIDTH_X  )      // center_x_o
                                       +(`IME_MV_WIDTH_Y  )      // center_y_o
                                       +(`IME_MV_WIDTH_X-1)      // length_x_o
                                       +(`IME_MV_WIDTH_Y-1)      // length_y_o
                                       +(2                )      // slope_o
                                       +(1                )      // downsample_o
                                       +(1                )      // partition_r
                                       +(1                ) ;    // use_feedback_o
  localparam    CMD_DAT_WIDTH          = CMD_DAT_WIDTH_ONE
                                       *(1<<CMD_NUM_WIDTH ) ;



//---- wire / reg declaration ---------------------------------
  // global
  reg                             clk                   ;
  reg                             rstn                  ;
  // cfg              
  reg                             sys_start             ;
  wire                            sys_done              ;
  reg   [`PIC_WIDTH      -1 :0]   sys_all_x             ;
  reg   [`PIC_HEIGHT     -1 :0]   sys_all_y             ;
  reg                             sys_type              ;
  reg   [6               -1 :0]   sys_init_qp           ;
  reg                             sys_IinP_ena          ;
  reg                             sys_dbsao_ena         ;
  reg   [5               -1 :0]   sys_posi4x4bit        ;
  reg   [32-1:0]                  skip_cost_thresh_08   ;
  reg   [32-1:0]                  skip_cost_thresh_16   ;
  reg   [32-1:0]                  skip_cost_thresh_32   ;
  reg   [32-1:0]                  skip_cost_thresh_64   ;

  // rc cfg 
  reg   [32              -1 :0]   sys_rc_bitnum_i       ;
  reg   [16              -1 :0]   sys_rc_k              ;
  reg   [6               -1 :0]   sys_rc_roi_height     ;
  reg   [7               -1 :0]   sys_rc_roi_width      ;
  reg   [7               -1 :0]   sys_rc_roi_x          ;
  reg   [7               -1 :0]   sys_rc_roi_y          ;
  reg                             sys_rc_roi_enable     ;
  reg   [10              -1 :0]   sys_rc_L1_frame_byte  ;
  reg   [10              -1 :0]   sys_rc_L2_frame_byte  ;
  reg                             sys_rc_lcu_en         ;
  reg   [6               -1 :0]   sys_rc_max_qp         ;
  reg   [6               -1 :0]   sys_rc_min_qp         ;
  reg   [6               -1 :0]   sys_rc_delta_qp       ;

  //ime_cfg
  reg   [CMD_NUM_WIDTH   -1 :0]   cmd_num_i             ;
  reg   [CMD_DAT_WIDTH   -1 :0]   cmd_dat_i             ;

  // ext if 
  wire  [1-1               : 0]   extif_start_o         ; // ext mem load start
  reg   [1-1               : 0]   extif_done_i          ; // ext mem load done
  wire  [5-1               : 0]   extif_mode_o          ; // "ext mode: {load/store} {luma
  wire  [`PIC_X_WIDTH+6-1  : 0]   extif_x_o             ; // x in ref frame
  wire  [`PIC_Y_WIDTH+6-1  : 0]   extif_y_o             ; // y in ref frame
  wire  [8-1               : 0]   extif_width_o         ; // ref window width
  wire  [8-1               : 0]   extif_height_o        ; // ref window height
  reg                             extif_wren_i          ;
  reg                             extif_rden_i          ;
  reg   [16*`PIXEL_WIDTH-1 : 0]   extif_data_i          ; // ext data reg
  wire  [16*`PIXEL_WIDTH-1 : 0]   extif_data_o          ; // ext data outp

  // bs
  wire                            bs_val_o              ;
  wire  [8-1                :0]   bs_dat_o              ;

//--- main body ---------------------------------------------------
  // clk 
  initial begin 
    clk = 0; 
    forever #5 clk = ~clk ;
  end 

  // rstn
  initial begin 
    rstn = 0;
    #(10*`FULL_CLK);
    @(negedge clk );
    rstn = 1;
  end 

  h265enc_top u_enc_top(
    // global
    .clk                 ( clk                  ),
    .rstn                ( rstn                 ),
    // sys_cfg_if
    .sys_start_i         ( sys_start            ),
    .sys_type_i          ( sys_type             ),
    .sys_all_x_i         ( sys_all_x            ),
    .sys_all_y_i         ( sys_all_y            ),
    .sys_init_qp_i       ( sys_init_qp          ),
    .sys_done_o          ( sys_done             ),
    .sys_IinP_ena_i      ( sys_IinP_ena         ),
    .sys_db_ena_i        ( sys_dbsao_ena        ),
    .sys_sao_ena_i       ( sys_dbsao_ena        ),
    .sys_posi4x4bit_i    ( sys_posi4x4bit       ),
    // skip thresh
    .skip_cost_thresh_08 ( skip_cost_thresh_08  ),
    .skip_cost_thresh_16 ( skip_cost_thresh_16  ),
    .skip_cost_thresh_32 ( skip_cost_thresh_32  ),
    .skip_cost_thresh_64 ( skip_cost_thresh_64  ),
    // rc_cfg_if
    .sys_rc_mod64_sum_o  (                      ),
    .sys_rc_bitnum_i     ( sys_rc_bitnum_i      ),
    .sys_rc_k            ( sys_rc_k             ),
    .sys_rc_roi_height   ( sys_rc_roi_height    ),
    .sys_rc_roi_width    ( sys_rc_roi_width     ),
    .sys_rc_roi_x        ( sys_rc_roi_x         ),
    .sys_rc_roi_y        ( sys_rc_roi_y         ),
    .sys_rc_roi_enable   ( sys_rc_roi_enable    ),
    .sys_rc_L1_frame_byte( sys_rc_L1_frame_byte ),
    .sys_rc_L2_frame_byte( sys_rc_L2_frame_byte ),
    .sys_rc_lcu_en       ( sys_rc_lcu_en        ),
    .sys_rc_max_qp       ( sys_rc_max_qp        ),
    .sys_rc_min_qp       ( sys_rc_min_qp        ),
    .sys_rc_delta_qp     ( sys_rc_delta_qp      ),
    // ime_cfg_if
    .sys_ime_cmd_num_i   ( cmd_num_i            ),
    .sys_ime_cmd_dat_i   ( cmd_dat_i            ),
    // ext_if
    .extif_start_o       ( extif_start_o        ),
    .extif_done_i        ( extif_done_i         ),
    .extif_mode_o        ( extif_mode_o         ),
    .extif_x_o           ( extif_x_o            ),
    .extif_y_o           ( extif_y_o            ),
    .extif_width_o       ( extif_width_o        ),
    .extif_height_o      ( extif_height_o       ),
    .extif_wren_i        ( extif_wren_i         ),
    .extif_rden_i        ( extif_rden_i         ),
    .extif_data_i        ( extif_data_i         ),
    .extif_data_o        ( extif_data_o         ),
    // bs_if
    .bs_val_o            ( bs_val_o             ),
    .bs_dat_o            ( bs_dat_o             )
    );


  // fake ext memory : para, memory & h_w_A
  parameter LOAD_CUR_SUB      = 01 ,
            LOAD_REF_SUB      = 02 ,
            LOAD_CUR_LUMA     = 03 ,
            LOAD_REF_LUMA     = 04 ,
            LOAD_CUR_CHROMA   = 05 ,
            LOAD_REF_CHROMA   = 06 ,
            LOAD_DB_LUMA      = 07 ,
            LOAD_DB_CHROMA    = 08 ,
            STORE_DB_LUMA     = 09 ,
            STORE_DB_CHROMA   = 10 ;

  // ori array
  reg [`PIXEL_WIDTH-1 :0]     ext_ori_yuv [`FRAME_WIDTH*`FRAME_HEIGHT*3/2-1:0] ;
  // rec array
  reg [`PIXEL_WIDTH-1 :0]     ext_rec_yuv [`FRAME_WIDTH*`FRAME_HEIGHT*3/2-1:0] ;
  // rec array from f265
  reg [`PIXEL_WIDTH-1 :0]     f265_rec_yuv [`FRAME_WIDTH*`FRAME_HEIGHT*3/2-1:0] ;
  // ref array
  reg [`PIXEL_WIDTH-1 :0]     ext_ref_yuv [`FRAME_WIDTH*`FRAME_HEIGHT*3/2-1:0] ;
  // for check
  reg   [16*`PIXEL_WIDTH-1 : 0]   f265_data             ;

  // for debug
  reg [`PIXEL_WIDTH-1:0] ext_debug_yuv_00 ,ext_debug_yuv_01 ,ext_debug_yuv_02 ,ext_debug_yuv_03 ;
  reg [`PIXEL_WIDTH-1:0] ext_debug_yuv_04 ,ext_debug_yuv_05 ,ext_debug_yuv_06 ,ext_debug_yuv_07 ;
  reg [`PIXEL_WIDTH-1:0] ext_debug_yuv_08 ,ext_debug_yuv_09 ,ext_debug_yuv_10 ,ext_debug_yuv_11 ;
  reg [`PIXEL_WIDTH-1:0] ext_debug_yuv_12 ,ext_debug_yuv_13 ,ext_debug_yuv_14 ,ext_debug_yuv_15 ;

  integer ext_height ;
  integer ext_width ;
  integer ext_addr; 

  integer   fp_cfg ;
  integer   fp_ori ;
  integer   fp_rec ;
  integer   fp_ref ;
  integer   fp_init ;
  integer   fp_check_bs ;
  integer   frame_num ;
  integer   frame_encoded ;
  integer   hw_ref_valid ;
  integer   pxl_cnt ;
  integer   pxl_adr ;
  reg [`PIXEL_WIDTH-1:0] ext_tmp_yuv ;
  integer   bs_byte_cnt ;
  reg [8-1 :0] check_bs ;

  // command
  reg signed [`IME_MV_WIDTH_X-1 :0]     center_x_r     ;
  reg signed [`IME_MV_WIDTH_Y-1 :0]     center_y_r     ;
  reg        [`IME_MV_WIDTH_X-2 :0]     length_x_r     ;
  reg        [`IME_MV_WIDTH_Y-2 :0]     length_y_r     ;
  reg        [2              -1 :0]     slope_r        ;
  reg                                   downsample_r   ;
  reg                                   partition_r    ;
  reg                                   use_feedback_r ;

  integer                               ime_cfg        ;
  integer                               fp_ime_cfg     ;
  reg signed [31                :0]     ime_cfg_dat    ; 
  integer                               rc_cfg         ;

  integer fp_reg_k ;
  integer fp_frame_qp ;

  task automatic check_file_open;
    input integer fd;
    input string file_name;
    begin
      if (fd == 0) begin
        $fatal(1, "ERROR: failed to open required file %s", file_name);
      end
    end
  endtask

  // fake ext memory : reponse logic
  initial begin
    extif_done_i = 0 ;
    extif_wren_i = 0 ;
    extif_data_i = 0 ;
  
    forever begin
      @(negedge extif_start_o );
      case( extif_mode_o )
        LOAD_CUR_LUMA   : // load luma component of current LCU: line in
                          begin            
                                            @(negedge clk );
                                            for( ext_height=0 ;ext_height<extif_height_o ;ext_height=ext_height+1 ) begin
                                              for( ext_width=0 ;ext_width<extif_width_o ;ext_width=ext_width+16 ) begin
                                                extif_wren_i = 1 ;
                                                ext_addr = (extif_y_o+ext_height)*`FRAME_WIDTH+extif_x_o+ext_width;
                                                extif_data_i = { ext_ori_yuv[ext_addr+00] ,ext_ori_yuv[ext_addr+01] ,ext_ori_yuv[ext_addr+02] ,ext_ori_yuv[ext_addr+03]
                                                                ,ext_ori_yuv[ext_addr+04] ,ext_ori_yuv[ext_addr+05] ,ext_ori_yuv[ext_addr+06] ,ext_ori_yuv[ext_addr+07]
                                                                ,ext_ori_yuv[ext_addr+08] ,ext_ori_yuv[ext_addr+09] ,ext_ori_yuv[ext_addr+10] ,ext_ori_yuv[ext_addr+11]
                                                                ,ext_ori_yuv[ext_addr+12] ,ext_ori_yuv[ext_addr+13] ,ext_ori_yuv[ext_addr+14] ,ext_ori_yuv[ext_addr+15]
                                                               };
                                                { ext_debug_yuv_00 ,ext_debug_yuv_01 ,ext_debug_yuv_02 ,ext_debug_yuv_03
                                                 ,ext_debug_yuv_04 ,ext_debug_yuv_05 ,ext_debug_yuv_06 ,ext_debug_yuv_07
                                                 ,ext_debug_yuv_08 ,ext_debug_yuv_09 ,ext_debug_yuv_10 ,ext_debug_yuv_11
                                                 ,ext_debug_yuv_12 ,ext_debug_yuv_13 ,ext_debug_yuv_14 ,ext_debug_yuv_15
                                                } = extif_data_i ;
                                                @(negedge clk );
                                              end
                                            end
                                            extif_wren_i = 0 ;
                                            #100 ;
                                            @(negedge clk)
                                            extif_done_i = 1 ;
                                            @(negedge clk)
                                            extif_done_i = 0 ;
                          end
        LOAD_REF_LUMA   : // load luma component of reference LCU: line in
                          begin             
                                            @(negedge clk );
                                            for( ext_height=0 ;ext_height<extif_height_o ;ext_height=ext_height+1 ) begin
                                              for( ext_width=0 ;ext_width<extif_width_o ;ext_width=ext_width+16 ) begin
                                                extif_wren_i = 1 ;
                                                ext_addr = (extif_y_o+ext_height)*`FRAME_WIDTH+extif_x_o+ext_width;
                                                extif_data_i = { ext_ref_yuv[ext_addr+00] ,ext_ref_yuv[ext_addr+01] ,ext_ref_yuv[ext_addr+02] ,ext_ref_yuv[ext_addr+03]
                                                                ,ext_ref_yuv[ext_addr+04] ,ext_ref_yuv[ext_addr+05] ,ext_ref_yuv[ext_addr+06] ,ext_ref_yuv[ext_addr+07]
                                                                ,ext_ref_yuv[ext_addr+08] ,ext_ref_yuv[ext_addr+09] ,ext_ref_yuv[ext_addr+10] ,ext_ref_yuv[ext_addr+11]
                                                                ,ext_ref_yuv[ext_addr+12] ,ext_ref_yuv[ext_addr+13] ,ext_ref_yuv[ext_addr+14] ,ext_ref_yuv[ext_addr+15]
                                                               };
                                                { ext_debug_yuv_00 ,ext_debug_yuv_01 ,ext_debug_yuv_02 ,ext_debug_yuv_03
                                                 ,ext_debug_yuv_04 ,ext_debug_yuv_05 ,ext_debug_yuv_06 ,ext_debug_yuv_07
                                                 ,ext_debug_yuv_08 ,ext_debug_yuv_09 ,ext_debug_yuv_10 ,ext_debug_yuv_11
                                                 ,ext_debug_yuv_12 ,ext_debug_yuv_13 ,ext_debug_yuv_14 ,ext_debug_yuv_15
                                                } = extif_data_i ;
                                                @(negedge clk );
                                              end
                                            end
                                            extif_wren_i = 0 ;
                                            #100 ;
                                            @(negedge clk)
                                            extif_done_i = 1 ;
                                            @(negedge clk)
                                            extif_done_i = 0 ;
                          end
        LOAD_CUR_CHROMA : // load chroma component of current LCU: line in, all u then all v
                          begin             
                                            @(negedge clk );
                                            for( ext_height=0 ;ext_height<extif_height_o/2 ;ext_height=ext_height+1 ) begin
                                              for( ext_width=0 ;ext_width<extif_width_o ;ext_width=ext_width+16 ) begin
                                                extif_wren_i = 1 ;
                                                ext_addr = `FRAME_WIDTH*`FRAME_HEIGHT+(extif_y_o/2+ext_height)*`FRAME_WIDTH+extif_x_o+ext_width;
                                                extif_data_i = { ext_ori_yuv[ext_addr+00] ,ext_ori_yuv[ext_addr+01] ,ext_ori_yuv[ext_addr+02] ,ext_ori_yuv[ext_addr+03]
                                                                ,ext_ori_yuv[ext_addr+04] ,ext_ori_yuv[ext_addr+05] ,ext_ori_yuv[ext_addr+06] ,ext_ori_yuv[ext_addr+07]
                                                                ,ext_ori_yuv[ext_addr+08] ,ext_ori_yuv[ext_addr+09] ,ext_ori_yuv[ext_addr+10] ,ext_ori_yuv[ext_addr+11]
                                                                ,ext_ori_yuv[ext_addr+12] ,ext_ori_yuv[ext_addr+13] ,ext_ori_yuv[ext_addr+14] ,ext_ori_yuv[ext_addr+15]
                                                               };
                                                { ext_debug_yuv_00 ,ext_debug_yuv_01 ,ext_debug_yuv_02 ,ext_debug_yuv_03
                                                 ,ext_debug_yuv_04 ,ext_debug_yuv_05 ,ext_debug_yuv_06 ,ext_debug_yuv_07
                                                 ,ext_debug_yuv_08 ,ext_debug_yuv_09 ,ext_debug_yuv_10 ,ext_debug_yuv_11
                                                 ,ext_debug_yuv_12 ,ext_debug_yuv_13 ,ext_debug_yuv_14 ,ext_debug_yuv_15
                                                } = extif_data_i ;
                                                @(negedge clk );
                                              end
                                            end
                                            extif_wren_i = 0 ;
                                            #100 ;
                                            @(negedge clk)
                                            extif_done_i = 1 ;
                                            @(negedge clk)
                                            extif_done_i = 0 ;
                          end
        LOAD_REF_CHROMA : // load chroma component of reference LCU: line in, all u then all v
                          begin             
                                            @(negedge clk );
                                            for( ext_height=0 ;ext_height<extif_height_o/2 ;ext_height=ext_height+1 ) begin
                                              for( ext_width=0 ;ext_width<extif_width_o ;ext_width=ext_width+16 ) begin
                                                extif_wren_i = 1 ;
                                                ext_addr  = `FRAME_WIDTH*`FRAME_HEIGHT+(extif_y_o/2+ext_height)*`FRAME_WIDTH+extif_x_o+ext_width ;
                                                extif_data_i = { ext_ref_yuv[ext_addr+00] ,ext_ref_yuv[ext_addr+01] ,ext_ref_yuv[ext_addr+02] ,ext_ref_yuv[ext_addr+03]
                                                                ,ext_ref_yuv[ext_addr+04] ,ext_ref_yuv[ext_addr+05] ,ext_ref_yuv[ext_addr+06] ,ext_ref_yuv[ext_addr+07]
                                                                ,ext_ref_yuv[ext_addr+08] ,ext_ref_yuv[ext_addr+09] ,ext_ref_yuv[ext_addr+10] ,ext_ref_yuv[ext_addr+11]
                                                                ,ext_ref_yuv[ext_addr+12] ,ext_ref_yuv[ext_addr+13] ,ext_ref_yuv[ext_addr+14] ,ext_ref_yuv[ext_addr+15]
                                                               };
                                                { ext_debug_yuv_00 ,ext_debug_yuv_01 ,ext_debug_yuv_02 ,ext_debug_yuv_03
                                                 ,ext_debug_yuv_04 ,ext_debug_yuv_05 ,ext_debug_yuv_06 ,ext_debug_yuv_07
                                                 ,ext_debug_yuv_08 ,ext_debug_yuv_09 ,ext_debug_yuv_10 ,ext_debug_yuv_11
                                                 ,ext_debug_yuv_12 ,ext_debug_yuv_13 ,ext_debug_yuv_14 ,ext_debug_yuv_15
                                                } = extif_data_i ;
                                                @(negedge clk );
                                              end
                                            end
                                            extif_wren_i = 0 ;
                                            #100 ;
                                            @(negedge clk)
                                            extif_done_i = 1 ;
                                            @(negedge clk)
                                            extif_done_i = 0 ;
                          end
        LOAD_DB_LUMA    : // load deblocked results: line in
                          begin             
                                            @(negedge clk );
                                            for( ext_height=0 ;ext_height<extif_height_o ;ext_height=ext_height+1 ) begin
                                              for( ext_width=0 ;ext_width<extif_width_o ;ext_width=ext_width+16 ) begin
                                                extif_wren_i = 1 ;
                                                ext_addr = (extif_y_o+ext_height)*`FRAME_WIDTH+extif_x_o+ext_width ;
                                                extif_data_i = { ext_rec_yuv[ext_addr+00] ,ext_rec_yuv[ext_addr+01] ,ext_rec_yuv[ext_addr+02] ,ext_rec_yuv[ext_addr+03]
                                                                ,ext_rec_yuv[ext_addr+04] ,ext_rec_yuv[ext_addr+05] ,ext_rec_yuv[ext_addr+06] ,ext_rec_yuv[ext_addr+07]
                                                                ,ext_rec_yuv[ext_addr+08] ,ext_rec_yuv[ext_addr+09] ,ext_rec_yuv[ext_addr+10] ,ext_rec_yuv[ext_addr+11]
                                                                ,ext_rec_yuv[ext_addr+12] ,ext_rec_yuv[ext_addr+13] ,ext_rec_yuv[ext_addr+14] ,ext_rec_yuv[ext_addr+15]
                                                               };
                                                { ext_debug_yuv_00 ,ext_debug_yuv_01 ,ext_debug_yuv_02 ,ext_debug_yuv_03
                                                 ,ext_debug_yuv_04 ,ext_debug_yuv_05 ,ext_debug_yuv_06 ,ext_debug_yuv_07
                                                 ,ext_debug_yuv_08 ,ext_debug_yuv_09 ,ext_debug_yuv_10 ,ext_debug_yuv_11
                                                 ,ext_debug_yuv_12 ,ext_debug_yuv_13 ,ext_debug_yuv_14 ,ext_debug_yuv_15
                                                } = extif_data_i ;
                                                @(negedge clk );
                                              end
                                            end
                                            extif_wren_i = 0 ;
                                            #100 ;
                                            @(negedge clk)
                                            extif_done_i = 1 ;
                                            @(negedge clk)
                                            extif_done_i = 0 ;
                          end
        LOAD_DB_CHROMA :  // load deblocked results: line in
                          begin             
                                            @(negedge clk );
                                            for( ext_height=0 ;ext_height<extif_height_o/2 ;ext_height=ext_height+1 ) begin
                                              for( ext_width=0 ;ext_width<extif_width_o ;ext_width=ext_width+16 ) begin
                                                extif_wren_i = 1 ;
                                                ext_addr  = `FRAME_WIDTH*`FRAME_HEIGHT+(extif_y_o/2+ext_height)*`FRAME_WIDTH+extif_x_o+ext_width ;
                                                extif_data_i = { ext_rec_yuv[ext_addr+00] ,ext_rec_yuv[ext_addr+01] ,ext_rec_yuv[ext_addr+02] ,ext_rec_yuv[ext_addr+03]
                                                                ,ext_rec_yuv[ext_addr+04] ,ext_rec_yuv[ext_addr+05] ,ext_rec_yuv[ext_addr+06] ,ext_rec_yuv[ext_addr+07]
                                                                ,ext_rec_yuv[ext_addr+08] ,ext_rec_yuv[ext_addr+09] ,ext_rec_yuv[ext_addr+10] ,ext_rec_yuv[ext_addr+11]
                                                                ,ext_rec_yuv[ext_addr+12] ,ext_rec_yuv[ext_addr+13] ,ext_rec_yuv[ext_addr+14] ,ext_rec_yuv[ext_addr+15]
                                                               };
                                                { ext_debug_yuv_00 ,ext_debug_yuv_01 ,ext_debug_yuv_02 ,ext_debug_yuv_03
                                                 ,ext_debug_yuv_04 ,ext_debug_yuv_05 ,ext_debug_yuv_06 ,ext_debug_yuv_07
                                                 ,ext_debug_yuv_08 ,ext_debug_yuv_09 ,ext_debug_yuv_10 ,ext_debug_yuv_11
                                                 ,ext_debug_yuv_12 ,ext_debug_yuv_13 ,ext_debug_yuv_14 ,ext_debug_yuv_15
                                                } = extif_data_i ;
                                                @(negedge clk );
                                              end
                                            end
                                            extif_wren_i = 0 ;
                                            #100 ;
                                            @(negedge clk)
                                            extif_done_i = 1 ;
                                            @(negedge clk)
                                            extif_done_i = 0 ;
                          end
        STORE_DB_LUMA   : // dump deblocked results: line in
                          begin             
                                            @(negedge clk );
                                            for( ext_height=0 ;ext_height<extif_height_o ;ext_height=ext_height+1 ) begin
                                              for( ext_width=0 ;ext_width<extif_width_o ;ext_width=ext_width+16 ) begin
                                                extif_rden_i = 1 ;
                                                ext_addr = (extif_y_o+ext_height)*`FRAME_WIDTH+extif_x_o+ext_width ;
                                                { ext_rec_yuv[ext_addr+00] ,ext_rec_yuv[ext_addr+01] ,ext_rec_yuv[ext_addr+02] ,ext_rec_yuv[ext_addr+03]
                                                 ,ext_rec_yuv[ext_addr+04] ,ext_rec_yuv[ext_addr+05] ,ext_rec_yuv[ext_addr+06] ,ext_rec_yuv[ext_addr+07]
                                                 ,ext_rec_yuv[ext_addr+08] ,ext_rec_yuv[ext_addr+09] ,ext_rec_yuv[ext_addr+10] ,ext_rec_yuv[ext_addr+11]
                                                 ,ext_rec_yuv[ext_addr+12] ,ext_rec_yuv[ext_addr+13] ,ext_rec_yuv[ext_addr+14] ,ext_rec_yuv[ext_addr+15]
                                                 } = extif_data_o ;
                                                { ext_debug_yuv_00 ,ext_debug_yuv_01 ,ext_debug_yuv_02 ,ext_debug_yuv_03
                                                 ,ext_debug_yuv_04 ,ext_debug_yuv_05 ,ext_debug_yuv_06 ,ext_debug_yuv_07
                                                 ,ext_debug_yuv_08 ,ext_debug_yuv_09 ,ext_debug_yuv_10 ,ext_debug_yuv_11
                                                 ,ext_debug_yuv_12 ,ext_debug_yuv_13 ,ext_debug_yuv_14 ,ext_debug_yuv_15
                                                } = extif_data_o ;
                                                f265_data = { f265_rec_yuv[ext_addr+00] ,f265_rec_yuv[ext_addr+01] ,f265_rec_yuv[ext_addr+02] ,f265_rec_yuv[ext_addr+03]
                                                             ,f265_rec_yuv[ext_addr+04] ,f265_rec_yuv[ext_addr+05] ,f265_rec_yuv[ext_addr+06] ,f265_rec_yuv[ext_addr+07]
                                                             ,f265_rec_yuv[ext_addr+08] ,f265_rec_yuv[ext_addr+09] ,f265_rec_yuv[ext_addr+10] ,f265_rec_yuv[ext_addr+11]
                                                             ,f265_rec_yuv[ext_addr+12] ,f265_rec_yuv[ext_addr+13] ,f265_rec_yuv[ext_addr+14] ,f265_rec_yuv[ext_addr+15]
                                                             };
                                                `ifdef CHECK_REC
                                                if ( extif_data_o != f265_data && (extif_x_o+ext_width+15<`FRAME_WIDTH) && (extif_y_o+ext_height<`FRAME_HEIGHT)) begin 
                                                  $display("ERROR at REC LUMA, y = %d, x = %d, f265 is %2h, however h265 is %2h ", 
                                                            (extif_y_o+ext_height), (extif_x_o+ext_width), f265_data, extif_data_o );
                                                  $finish; 
                                                end // if
                                                `endif
                                                @(negedge clk );
                                              end
                                            end
                                            extif_rden_i = 0 ;
                                            #100 ;
                                            @(negedge clk)
                                            extif_done_i = 1 ;
                                            @(negedge clk)
                                            extif_done_i = 0 ;
                          end
        STORE_DB_CHROMA : // dump deblocked results: line in
                          begin             
                                            @(negedge clk );
                                            for( ext_height=0 ;ext_height<extif_height_o/2 ;ext_height=ext_height+1 ) begin
                                              for( ext_width=0 ;ext_width<extif_width_o ;ext_width=ext_width+16 ) begin
                                                extif_rden_i = 1 ;
                                                ext_addr =  `FRAME_WIDTH*`FRAME_HEIGHT+  (extif_y_o/2+ext_height)*`FRAME_WIDTH+extif_x_o+ext_width ;
                                                { ext_rec_yuv[ext_addr+00] ,ext_rec_yuv[ext_addr+01] ,ext_rec_yuv[ext_addr+02] ,ext_rec_yuv[ext_addr+03]
                                                 ,ext_rec_yuv[ext_addr+04] ,ext_rec_yuv[ext_addr+05] ,ext_rec_yuv[ext_addr+06] ,ext_rec_yuv[ext_addr+07]
                                                 ,ext_rec_yuv[ext_addr+08] ,ext_rec_yuv[ext_addr+09] ,ext_rec_yuv[ext_addr+10] ,ext_rec_yuv[ext_addr+11]
                                                 ,ext_rec_yuv[ext_addr+12] ,ext_rec_yuv[ext_addr+13] ,ext_rec_yuv[ext_addr+14] ,ext_rec_yuv[ext_addr+15]
                                                 } = extif_data_o ;
                                                { ext_debug_yuv_00 ,ext_debug_yuv_01 ,ext_debug_yuv_02 ,ext_debug_yuv_03
                                                 ,ext_debug_yuv_04 ,ext_debug_yuv_05 ,ext_debug_yuv_06 ,ext_debug_yuv_07
                                                 ,ext_debug_yuv_08 ,ext_debug_yuv_09 ,ext_debug_yuv_10 ,ext_debug_yuv_11
                                                 ,ext_debug_yuv_12 ,ext_debug_yuv_13 ,ext_debug_yuv_14 ,ext_debug_yuv_15
                                                } = extif_data_o ;

                                                f265_data = { f265_rec_yuv[ext_addr+00] ,f265_rec_yuv[ext_addr+01] ,f265_rec_yuv[ext_addr+02] ,f265_rec_yuv[ext_addr+03]
                                                             ,f265_rec_yuv[ext_addr+04] ,f265_rec_yuv[ext_addr+05] ,f265_rec_yuv[ext_addr+06] ,f265_rec_yuv[ext_addr+07]
                                                             ,f265_rec_yuv[ext_addr+08] ,f265_rec_yuv[ext_addr+09] ,f265_rec_yuv[ext_addr+10] ,f265_rec_yuv[ext_addr+11]
                                                             ,f265_rec_yuv[ext_addr+12] ,f265_rec_yuv[ext_addr+13] ,f265_rec_yuv[ext_addr+14] ,f265_rec_yuv[ext_addr+15]
                                                             };
                                                `ifdef CHECK_REC
                                                if ( extif_data_o != f265_data && (extif_x_o+ext_width+15<`FRAME_WIDTH) && (extif_y_o+ext_height<`FRAME_HEIGHT)) begin 
                                                  $display("ERROR at REC CHROMA, y = %d, x = %d, f265 is %2h, however h265 is %2h ", 
                                                            (extif_y_o+ext_height), (extif_x_o+ext_width), f265_data, extif_data_o );
                                                  $finish; 
                                                end // if
                                                `endif
                                                @(negedge clk );
                                              end
                                            end
                                            extif_rden_i = 0 ;
                                            #100 ;
                                            @(negedge clk) ;
                                            extif_done_i = 1 ;
                                            //$display("\t\t at %08d, Frame(%02d), LCU(%02d, %02d) done", 
                                            //                $time, frame_num, u_enc_top.ec_y, u_enc_top.ec_x);
                                            @(negedge clk)
                                            extif_done_i = 0 ;
                          end
        default         : // default response
                          begin             #100 ;
                                            @(negedge clk)
                                            extif_done_i = 1 ;
                                            @(negedge clk)
                                            extif_done_i = 0 ;
                          end
      endcase
    end
  end


//---- read yuv from file ------------------------------------------------------------

  `ifdef DISABLE_DBSAO
    initial begin 
      force u_enc_top.u_enc_core.u_dbsao_top.u_db_bs.tu_edge_o = 0;
      force u_enc_top.u_enc_core.u_dbsao_top.u_db_bs.pu_edge_o = 0;
      force u_enc_top.u_enc_core.u_dbsao_top.sao_data_o = 0;
      force u_enc_top.u_enc_core.u_dbsao_top.u_sao_top.y_sao_offset_r = 0;
      force u_enc_top.u_enc_core.u_dbsao_top.u_sao_top.u_sao_offset_r = 0;
      force u_enc_top.u_enc_core.u_dbsao_top.u_sao_top.v_sao_offset_r = 0;
    end 
  `endif 

  initial begin 
    // sys if 
    sys_type = `INTRA;
    sys_start = 0;
    sys_init_qp = `INITIAL_QP ;
    sys_all_x = `FRAME_WIDTH ;
    sys_all_y = `FRAME_HEIGHT ;
    sys_IinP_ena = `ENABLE_IinP;
    sys_dbsao_ena  = `ENABLE_DBSAO ;
    sys_posi4x4bit = `POSI4x4BIT ;
    skip_cost_thresh_08 = `SKIP_COST_THRESH_8  ;
    skip_cost_thresh_16 = `SKIP_COST_THRESH_16 ;
    skip_cost_thresh_32 = `SKIP_COST_THRESH_32 ;
    skip_cost_thresh_64 = `SKIP_COST_THRESH_64 ;
    // rate control cfg 
    sys_rc_k             = 0 ;
    sys_rc_bitnum_i      = 'd10000 ;
    sys_rc_roi_height    = 'd1  ;
    sys_rc_roi_width     = 'd1  ;
    sys_rc_roi_x         = 'd4  ;
    sys_rc_roi_y         = 'd2  ;
    sys_rc_roi_enable    = 0  ;
    sys_rc_L1_frame_byte = 'd100 ;
    sys_rc_L2_frame_byte = 'd300 ;
    sys_rc_lcu_en        = 1'b0 ;
    sys_rc_max_qp        = 'd51 ;
    sys_rc_min_qp        = 'd10 ;
    sys_rc_delta_qp      = 'd4  ;
    check_bs             = 0 ;
    bs_byte_cnt          = 0 ;
    // file 
    fp_ori = $fopen( `FILE_CUR_YUV, "r" );
    fp_rec = $fopen( `FILE_REC_YUV, "r" );
    fp_ref = $fopen( `FILE_REC_YUV, "r" );
    fp_check_bs = $fopen( `FILE_CHECK_BS, "r" );
    fp_ime_cfg = $fopen( `FILE_IME_CFG, "r" );
    fp_reg_k = $fopen(`FILE_REG_K, "r");
    fp_frame_qp = $fopen(`FILE_FRAME_QP, "r");

    check_file_open(fp_ori, `FILE_CUR_YUV);
    check_file_open(fp_rec, `FILE_REC_YUV);
    check_file_open(fp_ref, `FILE_REC_YUV);
    check_file_open(fp_check_bs, `FILE_CHECK_BS);
    check_file_open(fp_ime_cfg, `FILE_IME_CFG);
    check_file_open(fp_reg_k, `FILE_REG_K);
    check_file_open(fp_frame_qp, `FILE_FRAME_QP);

      // lcu index
      ime_cfg = $fscanf( fp_ime_cfg ,"%d" ,ime_cfg_dat );
      ime_cfg = $fscanf( fp_ime_cfg ,"%d" ,ime_cfg_dat );
      // frame size
      ime_cfg = $fscanf( fp_ime_cfg ,"%d" ,ime_cfg_dat );
      ime_cfg = $fscanf( fp_ime_cfg ,"%d" ,ime_cfg_dat );
      // cfg
      ime_cfg = $fscanf( fp_ime_cfg ,"%d" ,cmd_num_i   );
      // cfg - 0
      begin
        if (cmd_num_i>=0) begin
          ime_cfg = $fscanf( fp_ime_cfg, "%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n", center_x_r, center_y_r, length_x_r, length_y_r, slope_r, downsample_r, partition_r, use_feedback_r );
        end
        else begin
          center_x_r     = 0        ;
          center_y_r     = 0        ;
          length_x_r     = 0        ;
          length_y_r     = 0        ;
          slope_r        = 0        ;
          downsample_r   = 0        ;
          partition_r    = 0        ;
          use_feedback_r = 0        ;
        end
        cmd_dat_i      = { center_x_r
                          ,center_y_r
                          ,length_x_r
                          ,length_y_r
                          ,slope_r
                          ,downsample_r
                          ,partition_r
                          ,use_feedback_r
                          ,cmd_dat_i }>>CMD_DAT_WIDTH_ONE ;
      end
      // cfg - 1
      begin
        if (cmd_num_i>=1) begin
          ime_cfg = $fscanf( fp_ime_cfg, "%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n", center_x_r, center_y_r, length_x_r, length_y_r, slope_r, downsample_r, partition_r, use_feedback_r );
        end
        else begin
          center_x_r     = 0        ;
          center_y_r     = 0        ;
          length_x_r     = 0        ;
          length_y_r     = 0        ;
          slope_r        = 0        ;
          downsample_r   = 0        ;
          partition_r    = 0        ;
          use_feedback_r = 0        ;
        end
        cmd_dat_i      = { center_x_r
                          ,center_y_r
                          ,length_x_r
                          ,length_y_r
                          ,slope_r
                          ,downsample_r
                          ,partition_r
                          ,use_feedback_r
                          ,cmd_dat_i }>>CMD_DAT_WIDTH_ONE ;
      end
      // cfg - 2
      begin
        if (cmd_num_i>=2) begin
          ime_cfg = $fscanf( fp_ime_cfg, "%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n", center_x_r, center_y_r, length_x_r, length_y_r, slope_r, downsample_r, partition_r, use_feedback_r );
        end
        else begin
          center_x_r     = 0        ;
          center_y_r     = 0        ;
          length_x_r     = 0        ;
          length_y_r     = 0        ;
          slope_r        = 0        ;
          downsample_r   = 0        ;
          partition_r    = 0        ;
          use_feedback_r = 0        ;
        end
        cmd_dat_i    = { center_x_r
                        ,center_y_r
                        ,length_x_r
                        ,length_y_r
                        ,slope_r
                        ,downsample_r
                        ,partition_r
                        ,use_feedback_r
                        ,cmd_dat_i }>>CMD_DAT_WIDTH_ONE ;
      end
      // cfg - 3
      begin
        if (cmd_num_i>=3) begin
          ime_cfg = $fscanf( fp_ime_cfg, "%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n", center_x_r, center_y_r, length_x_r, length_y_r, slope_r, downsample_r, partition_r, use_feedback_r );
        end
        else begin
          center_x_r     = 0        ;
          center_y_r     = 0        ;
          length_x_r     = 0        ;
          length_y_r     = 0        ;
          slope_r        = 0        ;
          downsample_r   = 0        ;
          partition_r    = 0        ;
          use_feedback_r = 0        ;
        end
        cmd_dat_i    = { center_x_r
                        ,center_y_r
                        ,length_x_r
                        ,length_y_r
                        ,slope_r
                        ,downsample_r
                        ,partition_r
                        ,use_feedback_r
                        ,cmd_dat_i }>>CMD_DAT_WIDTH_ONE ;
      end
      // cfg - 4
      begin
        if (cmd_num_i>=4) begin
          ime_cfg = $fscanf( fp_ime_cfg, "%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n", center_x_r, center_y_r, length_x_r, length_y_r, slope_r, downsample_r, partition_r, use_feedback_r );
        end
        else begin
          center_x_r     = 0        ;
          center_y_r     = 0        ;
          length_x_r     = 0        ;
          length_y_r     = 0        ;
          slope_r        = 0        ;
          downsample_r   = 0        ;
          partition_r    = 0        ;
          use_feedback_r = 0        ;
        end
        cmd_dat_i    = { center_x_r
                        ,center_y_r
                        ,length_x_r
                        ,length_y_r
                        ,slope_r
                        ,downsample_r
                        ,partition_r
                        ,use_feedback_r
                        ,cmd_dat_i }>>CMD_DAT_WIDTH_ONE ;
      end
      // cfg - 5
      begin
        if (cmd_num_i>=5) begin
          ime_cfg = $fscanf( fp_ime_cfg, "%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n", center_x_r, center_y_r, length_x_r, length_y_r, slope_r, downsample_r, partition_r, use_feedback_r );
        end
        else begin
          center_x_r     = 0        ;
          center_y_r     = 0        ;
          length_x_r     = 0        ;
          length_y_r     = 0        ;
          slope_r        = 0        ;
          downsample_r   = 0        ;
          partition_r    = 0        ;
          use_feedback_r = 0        ;
        end
        cmd_dat_i    = { center_x_r
                        ,center_y_r
                        ,length_x_r
                        ,length_y_r
                        ,slope_r
                        ,downsample_r
                        ,partition_r
                        ,use_feedback_r
                        ,cmd_dat_i }>>CMD_DAT_WIDTH_ONE ;
      end
      // cfg - 6
      begin
        if (cmd_num_i>=6) begin
          ime_cfg = $fscanf( fp_ime_cfg, "%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n", center_x_r, center_y_r, length_x_r, length_y_r, slope_r, downsample_r, partition_r, use_feedback_r );
        end
        else begin
          center_x_r     = 0        ;
          center_y_r     = 0        ;
          length_x_r     = 0        ;
          length_y_r     = 0        ;
          slope_r        = 0        ;
          downsample_r   = 0        ;
          partition_r    = 0        ;
          use_feedback_r = 0        ;
        end
        cmd_dat_i    = { center_x_r
                        ,center_y_r
                        ,length_x_r
                        ,length_y_r
                        ,slope_r
                        ,downsample_r
                        ,partition_r
                        ,use_feedback_r
                        ,cmd_dat_i }>>CMD_DAT_WIDTH_ONE ;
      end
      // cfg - 7
      begin
        if (cmd_num_i>=7) begin
          ime_cfg = $fscanf( fp_ime_cfg, "%d\n%d\n%d\n%d\n%d\n%d\n%d\n%d\n", center_x_r, center_y_r, length_x_r, length_y_r, slope_r, downsample_r, partition_r, use_feedback_r );
        end
        else begin
          center_x_r     = 0        ;
          center_y_r     = 0        ;
          length_x_r     = 0        ;
          length_y_r     = 0        ;
          slope_r        = 0        ;
          downsample_r   = 0        ;
          partition_r    = 0        ;
          use_feedback_r = 0        ;
        end
        cmd_dat_i    = { center_x_r
                        ,center_y_r
                        ,length_x_r
                        ,length_y_r
                        ,slope_r
                        ,downsample_r
                        ,partition_r
                        ,use_feedback_r
                        ,cmd_dat_i }>>CMD_DAT_WIDTH_ONE ;
      end


    wait(rstn);

    $monitor( "\tat %08d, Frame Number = %02d, mb_x_first = %02d, mb_y_first = %02d",
          $time, frame_num, u_enc_top.u_enc_ctrl.pre_l_x_o, u_enc_top.u_enc_ctrl.pre_l_y_o );

    hw_ref_valid = 0;

    for ( frame_num = 0 ; frame_num < `FRAME_TOTAL; frame_num = frame_num + 1 ) begin 
      frame_encoded = 0;
      `ifdef FORMAT_NV12
        // initial ori_y
        for ( pxl_cnt = 0 ; pxl_cnt < `FRAME_WIDTH*`FRAME_HEIGHT*3/2 ; pxl_cnt = pxl_cnt + 1 ) begin 
          fp_init = $fread( ext_tmp_yuv, fp_ori ) ;
          if (fp_init == 0) begin
            $fatal(1, "ERROR: EOF while reading input frame %0d from %s", frame_num, `FILE_CUR_YUV);
          end
          ext_ori_yuv[pxl_cnt] = ext_tmp_yuv ;
        end // for pxl_cnt
  
  		if ( frame_num%`GOP_LENGTH != 0 && (`USE_HW_DPB == 0 || !hw_ref_valid) ) begin 
  			// initial f265 ref for check
    	    for ( pxl_cnt = 0 ; pxl_cnt < `FRAME_WIDTH*`FRAME_HEIGHT*3/2 ; pxl_cnt = pxl_cnt + 1 ) begin 
    	      fp_init = $fread( ext_tmp_yuv, fp_ref ) ;
    	      ext_ref_yuv[pxl_cnt] = ext_tmp_yuv ;
    	    end // for pxl_cnt
    	end 

        // initial f265 rec for check
        for ( pxl_cnt = 0 ; pxl_cnt < `FRAME_WIDTH*`FRAME_HEIGHT*3/2 ; pxl_cnt = pxl_cnt + 1 ) begin 
          fp_init = $fread( ext_tmp_yuv, fp_rec ) ;
          f265_rec_yuv[pxl_cnt] = ext_tmp_yuv ;
        end // for pxl_cnt
      `endif // format nv12

      `ifdef FORMAT_YUV 
        // initial ori_y
        for ( pxl_cnt = 0 ; pxl_cnt < `FRAME_WIDTH*`FRAME_HEIGHT*3/2 ; pxl_cnt = pxl_cnt + 1 ) begin 
          fp_init = $fread( ext_tmp_yuv, fp_ori ) ;
          if (fp_init == 0) begin
            $fatal(1, "ERROR: EOF while reading input frame %0d from %s", frame_num, `FILE_CUR_YUV);
          end
          if ( pxl_cnt < `FRAME_WIDTH*`FRAME_HEIGHT )
            ext_ori_yuv[pxl_cnt] = ext_tmp_yuv ;
          else if ( pxl_cnt < `FRAME_WIDTH*`FRAME_HEIGHT*5/4 ) begin  // u
            pxl_adr = `FRAME_WIDTH*`FRAME_HEIGHT + ((pxl_cnt - `FRAME_WIDTH*`FRAME_HEIGHT)/(`FRAME_WIDTH/2))*`FRAME_WIDTH + 2*(pxl_cnt%(`FRAME_WIDTH/2));
            ext_ori_yuv[pxl_adr] = ext_tmp_yuv ;
          end else begin // v
            pxl_adr = `FRAME_WIDTH*`FRAME_HEIGHT + ((pxl_cnt - `FRAME_WIDTH*`FRAME_HEIGHT*5/4)/(`FRAME_WIDTH/2))*`FRAME_WIDTH + 2*(pxl_cnt%(`FRAME_WIDTH/2))+1;
            ext_ori_yuv[pxl_adr] = ext_tmp_yuv ;
          end 
        end // for pxl_cnt
  
  		// initial f265 rec for check
  		if ( frame_num%`GOP_LENGTH != 0 && (`USE_HW_DPB == 0 || !hw_ref_valid) ) begin 
        	for ( pxl_cnt = 0 ; pxl_cnt < `FRAME_WIDTH*`FRAME_HEIGHT*3/2 ; pxl_cnt = pxl_cnt + 1 ) begin 
        	  fp_init = $fread( ext_tmp_yuv, fp_ref ) ;
        	  if ( pxl_cnt < `FRAME_WIDTH*`FRAME_HEIGHT )
        	    ext_ref_yuv[pxl_cnt] = ext_tmp_yuv ;
        	  else if ( pxl_cnt < `FRAME_WIDTH*`FRAME_HEIGHT*5/4 ) begin  // u
        	    pxl_adr = `FRAME_WIDTH*`FRAME_HEIGHT + ((pxl_cnt - `FRAME_WIDTH*`FRAME_HEIGHT)/(`FRAME_WIDTH/2))*`FRAME_WIDTH + 2*(pxl_cnt%(`FRAME_WIDTH/2));
        	    ext_ref_yuv[pxl_adr] = ext_tmp_yuv ;
        	  end else begin // v
        	    pxl_adr = `FRAME_WIDTH*`FRAME_HEIGHT + ((pxl_cnt - `FRAME_WIDTH*`FRAME_HEIGHT*5/4)/(`FRAME_WIDTH/2))*`FRAME_WIDTH + 2*(pxl_cnt%(`FRAME_WIDTH/2))+1;
        	    ext_ref_yuv[pxl_adr] = ext_tmp_yuv ;
        	  end 
        	end // for pxl_cnt
        end // end if frame num

        // initial f265 rec for check
        for ( pxl_cnt = 0 ; pxl_cnt < `FRAME_WIDTH*`FRAME_HEIGHT*3/2 ; pxl_cnt = pxl_cnt + 1 ) begin 
          fp_init = $fread( ext_tmp_yuv, fp_rec ) ;
          if ( pxl_cnt < `FRAME_WIDTH*`FRAME_HEIGHT )
            f265_rec_yuv[pxl_cnt] = ext_tmp_yuv ;
          else if ( pxl_cnt < `FRAME_WIDTH*`FRAME_HEIGHT*5/4 ) begin  // u
            pxl_adr = `FRAME_WIDTH*`FRAME_HEIGHT + ((pxl_cnt - `FRAME_WIDTH*`FRAME_HEIGHT)/(`FRAME_WIDTH/2))*`FRAME_WIDTH + 2*(pxl_cnt%(`FRAME_WIDTH/2));
            f265_rec_yuv[pxl_adr] = ext_tmp_yuv ;
          end else begin // v
            pxl_adr = `FRAME_WIDTH*`FRAME_HEIGHT + ((pxl_cnt - `FRAME_WIDTH*`FRAME_HEIGHT*5/4)/(`FRAME_WIDTH/2))*`FRAME_WIDTH + 2*(pxl_cnt%(`FRAME_WIDTH/2))+1;
            f265_rec_yuv[pxl_adr] = ext_tmp_yuv ;
          end 
        end // for pxl_cnt
      `endif // format yuv

      if ( frame_num%`GOP_LENGTH == 0 )
        sys_type = `INTRA;
      else 
        sys_type = `INTER ;

      if ( ( sys_type==`INTRA && `TEST_I == 1 )
        || ( sys_type==`INTER && `TEST_P == 1 ) 

        `ifdef CHECK_ONE_FRAME
          && (frame_num == `CHECK_FRAME_NUM)
        `endif

        ) begin 
        @(negedge clk );
        sys_start = 1 ;
        @(negedge clk );
        sys_start = 0 ;
        if ( sys_type==`INTRA)
        	$display("\t at %08d, starting INTRA ENCODING frame(%02d) ...", $time, frame_num);
        else 
        	$display("\t at %08d, starting INTER ENCODING frame(%02d) ...", $time, frame_num);
        @(posedge sys_done );
        	$display(" done ");
        frame_encoded = 1;
        #100 ;
      end 
      else begin 
        if ( sys_type==`INTRA)
        	$display("\t at %08d, skipping INTRA ENCODING frame(%02d) ...", $time, frame_num);
        else 
        	$display("\t at %08d, skipping INTER ENCODING frame(%02d) ...", $time, frame_num);
      end 

      // rc cfg 
      if ( frame_num > 0 ) begin 
        rc_cfg = $fscanf( fp_reg_k ,"%d" ,sys_rc_k ); 
        sys_rc_lcu_en        = 1'b0 ;
      end 
      rc_cfg = $fscanf( fp_frame_qp ,"%d" ,sys_init_qp );

    `ifdef AUTO_CHECK
    /*
      `ifdef CHECK_REC
        $display("******* START CHECK REC YUV ! ********* ");
        for ( pxl_cnt = 0 ; pxl_cnt < `FRAME_WIDTH*`FRAME_HEIGHT*3/2 ; pxl_cnt = pxl_cnt + 1 ) begin 
          if ( ext_rec_yuv[pxl_cnt] != f265_rec_yuv[pxl_cnt] ) begin 
            $display("ERROR at REC y = %d, x = %d, f265 is %2h, however h265 is %2h ", 
                      pxl_cnt/`FRAME_WIDTH, pxl_cnt%`FRAME_WIDTH, f265_rec_yuv[pxl_cnt], ext_rec_yuv[pxl_cnt]);
          end // if
        end // for pxl_cnt
      `endif 
    */
    `endif // auto check

      if (`USE_HW_DPB != 0 && frame_encoded) begin
        for ( pxl_cnt = 0 ; pxl_cnt < `FRAME_WIDTH*`FRAME_HEIGHT*3/2 ; pxl_cnt = pxl_cnt + 1 ) begin 
          if (^ext_rec_yuv[pxl_cnt] !== 1'bx)
            ext_ref_yuv[pxl_cnt] = ext_rec_yuv[pxl_cnt] ;
          else
            ext_ref_yuv[pxl_cnt] = `PIXEL_WIDTH'd128 ;
        end // for pxl_cnt
        hw_ref_valid = 1;
      end

    end // for frame_num

    $finish ;

  end 

  `ifdef CHECK_BS 
    always @ (posedge clk ) begin
          if (bs_val_o == 1) begin 
            fp_init = $fscanf(fp_check_bs, "%h", check_bs);
            if ( check_bs != bs_dat_o ) begin
              $display("ERROR at BS at bs_byte_cnt = %5d, f265 is %h, h265 is %h", bs_byte_cnt, check_bs, bs_dat_o);
	      $finish ;
            end
            bs_byte_cnt=bs_byte_cnt+1;
          end 
    end 
  `endif // check bs

  `ifdef RD_MONITOR
    integer rd_bs_bytes;
    integer rd_idx;
    integer rd_diff;
    real    rd_sse;
    real    rd_mse;
    real    rd_psnr;

    initial begin
      rd_bs_bytes = 0;
    end

    always @(posedge clk) begin
      if (sys_start) begin
        rd_bs_bytes = 0;
      end

      if (bs_val_o) begin
        rd_bs_bytes = rd_bs_bytes + 1;
      end

      if (sys_done) begin
        rd_sse = 0.0;
        for (rd_idx = 0; rd_idx < `FRAME_WIDTH*`FRAME_HEIGHT*3/2; rd_idx = rd_idx + 1) begin
          rd_diff = ext_ori_yuv[rd_idx] - ext_rec_yuv[rd_idx];
          rd_sse = rd_sse + rd_diff * rd_diff;
        end
        rd_mse = rd_sse / (`FRAME_WIDTH*`FRAME_HEIGHT*3/2);
        if (rd_mse == 0.0) begin
          rd_psnr = 99.999;
        end else begin
          rd_psnr = 10.0 * $ln((255.0*255.0) / rd_mse) / $ln(10.0);
        end
        $display("RD_RESULT frame=%0d qp=%0d dbsao=%0d bits=%0d psnr=%0.6f mse=%0.6f", frame_num, sys_init_qp, sys_dbsao_ena, rd_bs_bytes*8, rd_psnr, rd_mse);
      end
    end
  `endif

  `ifdef INLOOP_TRACE
    integer il_cycle;
    integer il_rec_done_count;
    integer il_db_start_count;
    integer il_db_done_count;
    integer il_db_modified_count;
    integer il_sao_nonzero_count;
    integer il_fetch_write_count;
    integer il_store_write_count;
    integer il_load_ref_count;
    integer il_ime_ref_read_count;
    integer il_fme_ref_read_count;
    integer il_mc_ref_read_count;
    integer il_idx;
    integer il_rec_sum;
    integer il_ref_sum;
    integer il_rec_known_count;
    integer il_ref_known_count;
    integer il_rec_ref_match_count;

    initial begin
      il_cycle = 0;
      il_rec_done_count = 0;
      il_db_start_count = 0;
      il_db_done_count = 0;
      il_db_modified_count = 0;
      il_sao_nonzero_count = 0;
      il_fetch_write_count = 0;
      il_store_write_count = 0;
      il_load_ref_count = 0;
      il_ime_ref_read_count = 0;
      il_fme_ref_read_count = 0;
      il_mc_ref_read_count = 0;
      il_rec_sum = 0;
      il_ref_sum = 0;
      il_rec_known_count = 0;
      il_ref_known_count = 0;
      il_rec_ref_match_count = 0;
    end

    always @(posedge clk) begin
      il_cycle <= il_cycle + 1;

      if (sys_start) begin
        il_rec_done_count = 0;
        il_db_start_count = 0;
        il_db_done_count = 0;
        il_db_modified_count = 0;
        il_sao_nonzero_count = 0;
        il_fetch_write_count = 0;
        il_store_write_count = 0;
        il_load_ref_count = 0;
        il_ime_ref_read_count = 0;
        il_fme_ref_read_count = 0;
        il_mc_ref_read_count = 0;
        $display("INLOOP_FRAME_START frame=%0d type=%0d dbsao=%0d cycle=%0d",
                 frame_num, sys_type, sys_dbsao_ena, il_cycle);
      end

      if (u_enc_top.rec_done)
        il_rec_done_count = il_rec_done_count + 1;

      if (u_enc_top.db_start) begin
        il_db_start_count = il_db_start_count + 1;
        $display("INLOOP_DB_AFTER_REC frame=%0d lcu_x=%0d lcu_y=%0d rec_done_count=%0d cycle=%0d",
                 frame_num, u_enc_top.db_x, u_enc_top.db_y, il_rec_done_count, il_cycle);
      end

      if (u_enc_top.db_done)
        il_db_done_count = il_db_done_count + 1;

      if (u_enc_top.u_enc_core.u_dbsao_top.p_o_w !== u_enc_top.u_enc_core.u_dbsao_top.p_i_w ||
          u_enc_top.u_enc_core.u_dbsao_top.q_o_w !== u_enc_top.u_enc_core.u_dbsao_top.q_i_w)
        il_db_modified_count = il_db_modified_count + 1;

      if (u_enc_top.u_enc_core.u_dbsao_top.sao_block_w != 128'd0 &&
          u_enc_top.u_enc_core.u_dbsao_top.u_sao_top.sao_data_o != 62'd0)
        il_sao_nonzero_count = il_sao_nonzero_count + 1;

      if (u_enc_top.fetch_wen_w)
        il_fetch_write_count = il_fetch_write_count + 1;

      if (extif_rden_i && (extif_mode_o == STORE_DB_LUMA || extif_mode_o == STORE_DB_CHROMA))
        il_store_write_count = il_store_write_count + 1;

      if (extif_wren_i && (extif_mode_o == LOAD_REF_LUMA || extif_mode_o == LOAD_REF_CHROMA))
        il_load_ref_count = il_load_ref_count + 1;

      if (u_enc_top.ime_ref_rden_w)
        il_ime_ref_read_count = il_ime_ref_read_count + 1;

      if (u_enc_top.fme_ref_rden_w)
        il_fme_ref_read_count = il_fme_ref_read_count + 1;

      if (u_enc_top.rec_ref_rd_ena_w)
        il_mc_ref_read_count = il_mc_ref_read_count + 1;

      if (sys_done) begin
        il_rec_sum = 0;
        il_ref_sum = 0;
        il_rec_known_count = 0;
        il_ref_known_count = 0;
        il_rec_ref_match_count = 0;
        for (il_idx = 0; il_idx < `FRAME_WIDTH*`FRAME_HEIGHT*3/2; il_idx = il_idx + 1) begin
          if (^ext_rec_yuv[il_idx] !== 1'bx) begin
            il_rec_sum = (il_rec_sum + ext_rec_yuv[il_idx]) & 32'h7fffffff;
            il_rec_known_count = il_rec_known_count + 1;
          end
          if (^ext_ref_yuv[il_idx] !== 1'bx) begin
            il_ref_sum = (il_ref_sum + ext_ref_yuv[il_idx]) & 32'h7fffffff;
            il_ref_known_count = il_ref_known_count + 1;
          end
          if ((^ext_rec_yuv[il_idx] !== 1'bx) && (^ext_ref_yuv[il_idx] !== 1'bx) &&
              ext_rec_yuv[il_idx] == ext_ref_yuv[il_idx])
            il_rec_ref_match_count = il_rec_ref_match_count + 1;
        end
        $display("INLOOP_FRAME_RESULT frame=%0d type=%0d dbsao=%0d rec_done=%0d db_start=%0d db_done=%0d db_modified_cycles=%0d sao_nonzero_cycles=%0d fetch_writes=%0d store_writes=%0d load_ref_words=%0d ime_ref_reads=%0d fme_ref_reads=%0d mc_ref_reads=%0d rec_sum=%0d ref_sum=%0d rec_known=%0d ref_known=%0d rec_ref_match=%0d",
                 frame_num, sys_type, sys_dbsao_ena, il_rec_done_count, il_db_start_count,
                 il_db_done_count, il_db_modified_count, il_sao_nonzero_count, il_fetch_write_count,
                 il_store_write_count, il_load_ref_count, il_ime_ref_read_count, il_fme_ref_read_count,
                 il_mc_ref_read_count, il_rec_sum, il_ref_sum, il_rec_known_count, il_ref_known_count,
                 il_rec_ref_match_count);
      end
    end
  `endif

  `ifdef THROUGHPUT_MONITOR
    integer throughput_cycle;

    initial begin
      throughput_cycle = 0;
    end

    always @(posedge clk) begin
      throughput_cycle <= throughput_cycle + 1;
      if (sys_start) begin
        $display("THROUGHPUT_START cycle=%0d time_ns=%0d frame=%0d width=%0d height=%0d", throughput_cycle, $time, frame_num, `FRAME_WIDTH, `FRAME_HEIGHT);
      end
      if (sys_done) begin
        $display("THROUGHPUT_DONE cycle=%0d time_ns=%0d frame=%0d", throughput_cycle, $time, frame_num);
      end
    end
  `endif

  `ifdef DBSAO_CYCLE_MONITOR
    integer dbsao_cycle;
    integer dbsao_frame_start_cycle;
    integer dbsao_start_cycle;
    integer dbsao_latency_cycles;
    integer dbsao_total_latency_cycles;
    integer dbsao_busy_state_cycles;
    integer dbsao_lcu_count;
    integer dbsao_frame_cycles;
    integer dbsao_pct_x100;
    integer dbsao_start_x;
    integer dbsao_start_y;

    initial begin
      dbsao_cycle = 0;
      dbsao_frame_start_cycle = 0;
      dbsao_start_cycle = 0;
      dbsao_latency_cycles = 0;
      dbsao_total_latency_cycles = 0;
      dbsao_busy_state_cycles = 0;
      dbsao_lcu_count = 0;
      dbsao_frame_cycles = 0;
      dbsao_pct_x100 = 0;
      dbsao_start_x = 0;
      dbsao_start_y = 0;
    end

    always @(posedge clk) begin
      dbsao_cycle <= dbsao_cycle + 1;

      if (!rstn) begin
        dbsao_frame_start_cycle = 0;
        dbsao_start_cycle = 0;
        dbsao_total_latency_cycles = 0;
        dbsao_busy_state_cycles = 0;
        dbsao_lcu_count = 0;
      end else begin
        if (sys_start) begin
          dbsao_frame_start_cycle = dbsao_cycle;
          dbsao_total_latency_cycles = 0;
          dbsao_busy_state_cycles = 0;
          dbsao_lcu_count = 0;
          $display("DBSAO_FRAME_START frame=%0d cycle=%0d width=%0d height=%0d",
                   frame_num, dbsao_cycle, `FRAME_WIDTH, `FRAME_HEIGHT);
        end

        if (u_enc_top.u_enc_core.u_dbsao_top.u_controller.state_o != 3'b000) begin
          dbsao_busy_state_cycles = dbsao_busy_state_cycles + 1;
        end

        if (u_enc_top.db_start) begin
          dbsao_start_cycle = dbsao_cycle;
          dbsao_start_x = u_enc_top.db_x;
          dbsao_start_y = u_enc_top.db_y;
          $display("DBSAO_LCU_START frame=%0d lcu_x=%0d lcu_y=%0d cycle=%0d",
                   frame_num, dbsao_start_x, dbsao_start_y, dbsao_cycle);
        end

        if (u_enc_top.db_done) begin
          dbsao_latency_cycles = dbsao_cycle - dbsao_start_cycle;
          dbsao_total_latency_cycles = dbsao_total_latency_cycles + dbsao_latency_cycles;
          dbsao_lcu_count = dbsao_lcu_count + 1;
          $display("DBSAO_LCU_DONE frame=%0d lcu_x=%0d lcu_y=%0d latency_cycles=%0d cycle=%0d",
                   frame_num, dbsao_start_x, dbsao_start_y, dbsao_latency_cycles, dbsao_cycle);
        end

        if (sys_done) begin
          dbsao_frame_cycles = dbsao_cycle - dbsao_frame_start_cycle;
          if (dbsao_frame_cycles != 0)
            dbsao_pct_x100 = (dbsao_total_latency_cycles * 10000) / dbsao_frame_cycles;
          else
            dbsao_pct_x100 = 0;
          $display("DBSAO_FRAME_RESULT frame=%0d frame_cycles=%0d dbsao_lcus=%0d dbsao_latency_sum=%0d dbsao_busy_state_cycles=%0d dbsao_pct_x100=%0d",
                   frame_num, dbsao_frame_cycles, dbsao_lcu_count, dbsao_total_latency_cycles,
                   dbsao_busy_state_cycles, dbsao_pct_x100);
        end
      end
    end
  `endif

  `ifdef BLOCK_CYCLE_MONITOR
    integer block_cycle;
    integer block_frame_start_cycle;
    integer block_frame_cycles;
    integer block_pct_x100;
    real    block_avg_real;
    real    block_pct_real;

    integer fetch_start_cycle;
    integer prei_start_cycle;
    integer posi_start_cycle;
    integer ime_start_cycle;
    integer fme_start_cycle;
    integer rec_start_cycle;
    integer db_start_cycle;
    integer ec_start_cycle;

    integer fetch_sum_cycles;
    integer prei_sum_cycles;
    integer posi_sum_cycles;
    integer ime_sum_cycles;
    integer fme_sum_cycles;
    integer rec_sum_cycles;
    integer db_sum_cycles;
    integer ec_sum_cycles;
    integer tq_active_cycles;

    integer fetch_count;
    integer prei_count;
    integer posi_count;
    integer ime_count;
    integer fme_count;
    integer rec_count;
    integer db_count;
    integer ec_count;
    integer tq_active_count;

    task automatic block_report;
      input string block_name;
      input integer count;
      input integer sum_cycles;
      input integer total_cycles;
      begin
        if (count != 0)
          block_avg_real = sum_cycles * 1.0 / count;
        else
          block_avg_real = 0.0;
        if (total_cycles != 0)
          block_pct_real = sum_cycles * 100.0 / total_cycles;
        else
          block_pct_real = 0.0;
        $display("BLOCK_CYCLE_RESULT frame=%0d block=%s count=%0d cycles_sum=%0d avg_cycles=%0.2f pct=%0.2f",
                 frame_num, block_name, count, sum_cycles, block_avg_real, block_pct_real);
      end
    endtask

    initial begin
      block_cycle = 0;
      block_frame_start_cycle = 0;
      block_frame_cycles = 0;
      block_pct_x100 = 0;
      block_avg_real = 0.0;
      block_pct_real = 0.0;
      fetch_start_cycle = 0;
      prei_start_cycle = 0;
      posi_start_cycle = 0;
      ime_start_cycle = 0;
      fme_start_cycle = 0;
      rec_start_cycle = 0;
      db_start_cycle = 0;
      ec_start_cycle = 0;
      fetch_sum_cycles = 0;
      prei_sum_cycles = 0;
      posi_sum_cycles = 0;
      ime_sum_cycles = 0;
      fme_sum_cycles = 0;
      rec_sum_cycles = 0;
      db_sum_cycles = 0;
      ec_sum_cycles = 0;
      tq_active_cycles = 0;
      fetch_count = 0;
      prei_count = 0;
      posi_count = 0;
      ime_count = 0;
      fme_count = 0;
      rec_count = 0;
      db_count = 0;
      ec_count = 0;
      tq_active_count = 0;
    end

    always @(posedge clk) begin
      block_cycle <= block_cycle + 1;

      if (!rstn) begin
        block_frame_start_cycle = 0;
        fetch_sum_cycles = 0;
        prei_sum_cycles = 0;
        posi_sum_cycles = 0;
        ime_sum_cycles = 0;
        fme_sum_cycles = 0;
        rec_sum_cycles = 0;
        db_sum_cycles = 0;
        ec_sum_cycles = 0;
        tq_active_cycles = 0;
        fetch_count = 0;
        prei_count = 0;
        posi_count = 0;
        ime_count = 0;
        fme_count = 0;
        rec_count = 0;
        db_count = 0;
        ec_count = 0;
        tq_active_count = 0;
      end else begin
        if (sys_start) begin
          block_frame_start_cycle = block_cycle;
          fetch_sum_cycles = 0;
          prei_sum_cycles = 0;
          posi_sum_cycles = 0;
          ime_sum_cycles = 0;
          fme_sum_cycles = 0;
          rec_sum_cycles = 0;
          db_sum_cycles = 0;
          ec_sum_cycles = 0;
          tq_active_cycles = 0;
          fetch_count = 0;
          prei_count = 0;
          posi_count = 0;
          ime_count = 0;
          fme_count = 0;
          rec_count = 0;
          db_count = 0;
          ec_count = 0;
          tq_active_count = 0;
        end

        if (u_enc_top.enc_start)   fetch_start_cycle = block_cycle;
        if (u_enc_top.prei_start)  prei_start_cycle  = block_cycle;
        if (u_enc_top.posi_start)  posi_start_cycle  = block_cycle;
        if (u_enc_top.ime_start)   ime_start_cycle   = block_cycle;
        if (u_enc_top.fme_start)   fme_start_cycle   = block_cycle;
        if (u_enc_top.rec_start)   rec_start_cycle   = block_cycle;
        if (u_enc_top.db_start)    db_start_cycle    = block_cycle;
        if (u_enc_top.ec_start)    ec_start_cycle    = block_cycle;

        if (u_enc_top.fetch_done) begin
          fetch_sum_cycles = fetch_sum_cycles + (block_cycle - fetch_start_cycle);
          fetch_count = fetch_count + 1;
        end
        if (u_enc_top.prei_done) begin
          prei_sum_cycles = prei_sum_cycles + (block_cycle - prei_start_cycle);
          prei_count = prei_count + 1;
        end
        if (u_enc_top.posi_done) begin
          posi_sum_cycles = posi_sum_cycles + (block_cycle - posi_start_cycle);
          posi_count = posi_count + 1;
        end
        if (u_enc_top.ime_done) begin
          ime_sum_cycles = ime_sum_cycles + (block_cycle - ime_start_cycle);
          ime_count = ime_count + 1;
        end
        if (u_enc_top.fme_done) begin
          fme_sum_cycles = fme_sum_cycles + (block_cycle - fme_start_cycle);
          fme_count = fme_count + 1;
        end
        if (u_enc_top.rec_done) begin
          rec_sum_cycles = rec_sum_cycles + (block_cycle - rec_start_cycle);
          rec_count = rec_count + 1;
        end
        if (u_enc_top.db_done) begin
          db_sum_cycles = db_sum_cycles + (block_cycle - db_start_cycle);
          db_count = db_count + 1;
        end
        if (u_enc_top.ec_done) begin
          ec_sum_cycles = ec_sum_cycles + (block_cycle - ec_start_cycle);
          ec_count = ec_count + 1;
        end

        if (u_enc_top.u_enc_core.u_rec_top.u_tq_top.tq_en_i) begin
          tq_active_cycles = tq_active_cycles + 1;
          tq_active_count = tq_active_count + 1;
        end

        if (sys_done) begin
          block_frame_cycles = block_cycle - block_frame_start_cycle;
          $display("BLOCK_FRAME_RESULT frame=%0d frame_cycles=%0d", frame_num, block_frame_cycles);
          block_report("FETCH", fetch_count, fetch_sum_cycles, block_frame_cycles);
          block_report("PREI", prei_count, prei_sum_cycles, block_frame_cycles);
          block_report("POSI", posi_count, posi_sum_cycles, block_frame_cycles);
          block_report("IME", ime_count, ime_sum_cycles, block_frame_cycles);
          block_report("FME", fme_count, fme_sum_cycles, block_frame_cycles);
          block_report("REC_TQ", rec_count, rec_sum_cycles, block_frame_cycles);
          block_report("TQ_ACTIVE", tq_active_count, tq_active_cycles, block_frame_cycles);
          block_report("DBSAO", db_count, db_sum_cycles, block_frame_cycles);
          block_report("CABAC", ec_count, ec_sum_cycles, block_frame_cycles);
        end
      end
    end
  `endif


//---- DUMP FSDB ---------------------------------------------------------------------

  `ifdef DUMP_FSDB

    initial begin
      #`DUMP_TIME ;
      $fsdbDumpfile( `DUMP_FILE );
      $fsdbDumpvars( `TB_NAME );
      #100 ;
      $display( "\t\t dump (fsdb) to this test is on !\n" );
    end

  `endif

  `ifdef DUMP_SHM

    initial begin
      #`DUMP_SHM_TIME ;
      $shm_open( `DUMP_SHM_FILE );
      $shm_probe( tb_top ,`DUMP_SHM_LEVEL );
      #100 ;
      $display( "\t\t dump (shm) to this test is on !\n" );
    end

  `endif


endmodule 
