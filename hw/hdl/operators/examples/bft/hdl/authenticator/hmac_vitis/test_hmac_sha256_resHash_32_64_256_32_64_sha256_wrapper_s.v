// ==============================================================
// RTL generated by Vitis HLS - High-Level Synthesis from C, C++ and OpenCL v2022.1 (64-bit)
// Version: 2022.1
// Copyright (C) Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// 
// ===========================================================

`timescale 1 ns / 1 ps 

module test_hmac_sha256_resHash_32_64_256_32_64_sha256_wrapper_s (
        kopad2Strm9_dout,
        kopad2Strm9_empty_n,
        kopad2Strm9_read,
        msgHashStrm10_dout,
        msgHashStrm10_empty_n,
        msgHashStrm10_read,
        eMsgHashStrm11_dout,
        eMsgHashStrm11_empty_n,
        eMsgHashStrm11_read,
        hshStrm_din,
        hshStrm_full_n,
        hshStrm_write,
        eHshStrm_din,
        eHshStrm_full_n,
        eHshStrm_write,
        ap_clk,
        ap_rst,
        ap_start,
        ap_done,
        ap_ready,
        ap_idle,
        ap_continue
);


input  [511:0] kopad2Strm9_dout;
input   kopad2Strm9_empty_n;
output   kopad2Strm9_read;
input  [255:0] msgHashStrm10_dout;
input   msgHashStrm10_empty_n;
output   msgHashStrm10_read;
input  [0:0] eMsgHashStrm11_dout;
input   eMsgHashStrm11_empty_n;
output   eMsgHashStrm11_read;
output  [255:0] hshStrm_din;
input   hshStrm_full_n;
output   hshStrm_write;
output  [0:0] eHshStrm_din;
input   eHshStrm_full_n;
output   eHshStrm_write;
input   ap_clk;
input   ap_rst;
input   ap_start;
output   ap_done;
output   ap_ready;
output   ap_idle;
input   ap_continue;

wire    mergeKopad_32_64_256_32_64_U0_ap_start;
wire    mergeKopad_32_64_256_32_64_U0_ap_done;
wire    mergeKopad_32_64_256_32_64_U0_ap_continue;
wire    mergeKopad_32_64_256_32_64_U0_ap_idle;
wire    mergeKopad_32_64_256_32_64_U0_ap_ready;
wire    mergeKopad_32_64_256_32_64_U0_start_out;
wire    mergeKopad_32_64_256_32_64_U0_start_write;
wire    mergeKopad_32_64_256_32_64_U0_kopad2Strm9_read;
wire    mergeKopad_32_64_256_32_64_U0_msgHashStrm10_read;
wire    mergeKopad_32_64_256_32_64_U0_eMsgHashStrm11_read;
wire   [31:0] mergeKopad_32_64_256_32_64_U0_mergeKopadStrm3_din;
wire    mergeKopad_32_64_256_32_64_U0_mergeKopadStrm3_write;
wire   [63:0] mergeKopad_32_64_256_32_64_U0_mergeKopadLenStrm4_din;
wire    mergeKopad_32_64_256_32_64_U0_mergeKopadLenStrm4_write;
wire   [0:0] mergeKopad_32_64_256_32_64_U0_eMergeKopadLenStrm5_din;
wire    mergeKopad_32_64_256_32_64_U0_eMergeKopadLenStrm5_write;
wire    hash_1_U0_ap_start;
wire    hash_1_U0_ap_done;
wire    hash_1_U0_ap_continue;
wire    hash_1_U0_ap_idle;
wire    hash_1_U0_ap_ready;
wire    hash_1_U0_mergeKopadStrm3_read;
wire    hash_1_U0_mergeKopadLenStrm4_read;
wire    hash_1_U0_eMergeKopadLenStrm5_read;
wire   [255:0] hash_1_U0_hshStrm_din;
wire    hash_1_U0_hshStrm_write;
wire   [0:0] hash_1_U0_eHshStrm_din;
wire    hash_1_U0_eHshStrm_write;
wire    mergeKopadStrm_full_n;
wire   [31:0] mergeKopadStrm_dout;
wire   [2:0] mergeKopadStrm_num_data_valid;
wire   [2:0] mergeKopadStrm_fifo_cap;
wire    mergeKopadStrm_empty_n;
wire    mergeKopadLenStrm_full_n;
wire   [63:0] mergeKopadLenStrm_dout;
wire   [2:0] mergeKopadLenStrm_num_data_valid;
wire   [2:0] mergeKopadLenStrm_fifo_cap;
wire    mergeKopadLenStrm_empty_n;
wire    eMergeKopadLenStrm_full_n;
wire   [0:0] eMergeKopadLenStrm_dout;
wire   [2:0] eMergeKopadLenStrm_num_data_valid;
wire   [2:0] eMergeKopadLenStrm_fifo_cap;
wire    eMergeKopadLenStrm_empty_n;
wire   [0:0] start_for_hash_1_U0_din;
wire    start_for_hash_1_U0_full_n;
wire   [0:0] start_for_hash_1_U0_dout;
wire    start_for_hash_1_U0_empty_n;

test_hmac_sha256_mergeKopad_32_64_256_32_64_s mergeKopad_32_64_256_32_64_U0(
    .ap_clk(ap_clk),
    .ap_rst(ap_rst),
    .ap_start(mergeKopad_32_64_256_32_64_U0_ap_start),
    .start_full_n(start_for_hash_1_U0_full_n),
    .ap_done(mergeKopad_32_64_256_32_64_U0_ap_done),
    .ap_continue(mergeKopad_32_64_256_32_64_U0_ap_continue),
    .ap_idle(mergeKopad_32_64_256_32_64_U0_ap_idle),
    .ap_ready(mergeKopad_32_64_256_32_64_U0_ap_ready),
    .start_out(mergeKopad_32_64_256_32_64_U0_start_out),
    .start_write(mergeKopad_32_64_256_32_64_U0_start_write),
    .kopad2Strm9_dout(kopad2Strm9_dout),
    .kopad2Strm9_num_data_valid(3'd0),
    .kopad2Strm9_fifo_cap(3'd0),
    .kopad2Strm9_empty_n(kopad2Strm9_empty_n),
    .kopad2Strm9_read(mergeKopad_32_64_256_32_64_U0_kopad2Strm9_read),
    .msgHashStrm10_dout(msgHashStrm10_dout),
    .msgHashStrm10_num_data_valid(3'd0),
    .msgHashStrm10_fifo_cap(3'd0),
    .msgHashStrm10_empty_n(msgHashStrm10_empty_n),
    .msgHashStrm10_read(mergeKopad_32_64_256_32_64_U0_msgHashStrm10_read),
    .eMsgHashStrm11_dout(eMsgHashStrm11_dout),
    .eMsgHashStrm11_num_data_valid(3'd0),
    .eMsgHashStrm11_fifo_cap(3'd0),
    .eMsgHashStrm11_empty_n(eMsgHashStrm11_empty_n),
    .eMsgHashStrm11_read(mergeKopad_32_64_256_32_64_U0_eMsgHashStrm11_read),
    .mergeKopadStrm3_din(mergeKopad_32_64_256_32_64_U0_mergeKopadStrm3_din),
    .mergeKopadStrm3_num_data_valid(mergeKopadStrm_num_data_valid),
    .mergeKopadStrm3_fifo_cap(mergeKopadStrm_fifo_cap),
    .mergeKopadStrm3_full_n(mergeKopadStrm_full_n),
    .mergeKopadStrm3_write(mergeKopad_32_64_256_32_64_U0_mergeKopadStrm3_write),
    .mergeKopadLenStrm4_din(mergeKopad_32_64_256_32_64_U0_mergeKopadLenStrm4_din),
    .mergeKopadLenStrm4_num_data_valid(mergeKopadLenStrm_num_data_valid),
    .mergeKopadLenStrm4_fifo_cap(mergeKopadLenStrm_fifo_cap),
    .mergeKopadLenStrm4_full_n(mergeKopadLenStrm_full_n),
    .mergeKopadLenStrm4_write(mergeKopad_32_64_256_32_64_U0_mergeKopadLenStrm4_write),
    .eMergeKopadLenStrm5_din(mergeKopad_32_64_256_32_64_U0_eMergeKopadLenStrm5_din),
    .eMergeKopadLenStrm5_num_data_valid(eMergeKopadLenStrm_num_data_valid),
    .eMergeKopadLenStrm5_fifo_cap(eMergeKopadLenStrm_fifo_cap),
    .eMergeKopadLenStrm5_full_n(eMergeKopadLenStrm_full_n),
    .eMergeKopadLenStrm5_write(mergeKopad_32_64_256_32_64_U0_eMergeKopadLenStrm5_write)
);

test_hmac_sha256_hash_1 hash_1_U0(
    .ap_clk(ap_clk),
    .ap_rst(ap_rst),
    .ap_start(hash_1_U0_ap_start),
    .ap_done(hash_1_U0_ap_done),
    .ap_continue(hash_1_U0_ap_continue),
    .ap_idle(hash_1_U0_ap_idle),
    .ap_ready(hash_1_U0_ap_ready),
    .mergeKopadStrm3_dout(mergeKopadStrm_dout),
    .mergeKopadStrm3_num_data_valid(mergeKopadStrm_num_data_valid),
    .mergeKopadStrm3_fifo_cap(mergeKopadStrm_fifo_cap),
    .mergeKopadStrm3_empty_n(mergeKopadStrm_empty_n),
    .mergeKopadStrm3_read(hash_1_U0_mergeKopadStrm3_read),
    .mergeKopadLenStrm4_dout(mergeKopadLenStrm_dout),
    .mergeKopadLenStrm4_num_data_valid(mergeKopadLenStrm_num_data_valid),
    .mergeKopadLenStrm4_fifo_cap(mergeKopadLenStrm_fifo_cap),
    .mergeKopadLenStrm4_empty_n(mergeKopadLenStrm_empty_n),
    .mergeKopadLenStrm4_read(hash_1_U0_mergeKopadLenStrm4_read),
    .eMergeKopadLenStrm5_dout(eMergeKopadLenStrm_dout),
    .eMergeKopadLenStrm5_num_data_valid(eMergeKopadLenStrm_num_data_valid),
    .eMergeKopadLenStrm5_fifo_cap(eMergeKopadLenStrm_fifo_cap),
    .eMergeKopadLenStrm5_empty_n(eMergeKopadLenStrm_empty_n),
    .eMergeKopadLenStrm5_read(hash_1_U0_eMergeKopadLenStrm5_read),
    .hshStrm_din(hash_1_U0_hshStrm_din),
    .hshStrm_full_n(hshStrm_full_n),
    .hshStrm_write(hash_1_U0_hshStrm_write),
    .eHshStrm_din(hash_1_U0_eHshStrm_din),
    .eHshStrm_full_n(eHshStrm_full_n),
    .eHshStrm_write(hash_1_U0_eHshStrm_write)
);

test_hmac_sha256_fifo_w32_d4_D mergeKopadStrm_U(
    .clk(ap_clk),
    .reset(ap_rst),
    .if_read_ce(1'b1),
    .if_write_ce(1'b1),
    .if_din(mergeKopad_32_64_256_32_64_U0_mergeKopadStrm3_din),
    .if_full_n(mergeKopadStrm_full_n),
    .if_write(mergeKopad_32_64_256_32_64_U0_mergeKopadStrm3_write),
    .if_dout(mergeKopadStrm_dout),
    .if_num_data_valid(mergeKopadStrm_num_data_valid),
    .if_fifo_cap(mergeKopadStrm_fifo_cap),
    .if_empty_n(mergeKopadStrm_empty_n),
    .if_read(hash_1_U0_mergeKopadStrm3_read)
);

test_hmac_sha256_fifo_w64_d4_D_x mergeKopadLenStrm_U(
    .clk(ap_clk),
    .reset(ap_rst),
    .if_read_ce(1'b1),
    .if_write_ce(1'b1),
    .if_din(mergeKopad_32_64_256_32_64_U0_mergeKopadLenStrm4_din),
    .if_full_n(mergeKopadLenStrm_full_n),
    .if_write(mergeKopad_32_64_256_32_64_U0_mergeKopadLenStrm4_write),
    .if_dout(mergeKopadLenStrm_dout),
    .if_num_data_valid(mergeKopadLenStrm_num_data_valid),
    .if_fifo_cap(mergeKopadLenStrm_fifo_cap),
    .if_empty_n(mergeKopadLenStrm_empty_n),
    .if_read(hash_1_U0_mergeKopadLenStrm4_read)
);

test_hmac_sha256_fifo_w1_d4_D_x eMergeKopadLenStrm_U(
    .clk(ap_clk),
    .reset(ap_rst),
    .if_read_ce(1'b1),
    .if_write_ce(1'b1),
    .if_din(mergeKopad_32_64_256_32_64_U0_eMergeKopadLenStrm5_din),
    .if_full_n(eMergeKopadLenStrm_full_n),
    .if_write(mergeKopad_32_64_256_32_64_U0_eMergeKopadLenStrm5_write),
    .if_dout(eMergeKopadLenStrm_dout),
    .if_num_data_valid(eMergeKopadLenStrm_num_data_valid),
    .if_fifo_cap(eMergeKopadLenStrm_fifo_cap),
    .if_empty_n(eMergeKopadLenStrm_empty_n),
    .if_read(hash_1_U0_eMergeKopadLenStrm5_read)
);

test_hmac_sha256_start_for_hash_1_U0 start_for_hash_1_U0_U(
    .clk(ap_clk),
    .reset(ap_rst),
    .if_read_ce(1'b1),
    .if_write_ce(1'b1),
    .if_din(start_for_hash_1_U0_din),
    .if_full_n(start_for_hash_1_U0_full_n),
    .if_write(mergeKopad_32_64_256_32_64_U0_start_write),
    .if_dout(start_for_hash_1_U0_dout),
    .if_empty_n(start_for_hash_1_U0_empty_n),
    .if_read(hash_1_U0_ap_ready)
);

assign ap_done = hash_1_U0_ap_done;

assign ap_idle = (mergeKopad_32_64_256_32_64_U0_ap_idle & hash_1_U0_ap_idle);

assign ap_ready = mergeKopad_32_64_256_32_64_U0_ap_ready;

assign eHshStrm_din = hash_1_U0_eHshStrm_din;

assign eHshStrm_write = hash_1_U0_eHshStrm_write;

assign eMsgHashStrm11_read = mergeKopad_32_64_256_32_64_U0_eMsgHashStrm11_read;

assign hash_1_U0_ap_continue = ap_continue;

assign hash_1_U0_ap_start = start_for_hash_1_U0_empty_n;

assign hshStrm_din = hash_1_U0_hshStrm_din;

assign hshStrm_write = hash_1_U0_hshStrm_write;

assign kopad2Strm9_read = mergeKopad_32_64_256_32_64_U0_kopad2Strm9_read;

assign mergeKopad_32_64_256_32_64_U0_ap_continue = 1'b1;

assign mergeKopad_32_64_256_32_64_U0_ap_start = ap_start;

assign msgHashStrm10_read = mergeKopad_32_64_256_32_64_U0_msgHashStrm10_read;

assign start_for_hash_1_U0_din = 1'b1;

endmodule //test_hmac_sha256_resHash_32_64_256_32_64_sha256_wrapper_s