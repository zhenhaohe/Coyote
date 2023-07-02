/*
 * Copyright (c) 2021, Systems Group, ETH Zurich
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holder nor the names of its contributors
 * may be used to endorse or promote products derived from this software
 * without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */
`timescale 1ns / 1ps

`include "axi_macros.svh"
`include "lynx_macros.svh"

import lynxTypes::*;
import bftTypes::*;

module sha256_pipeline_secworks
#( 
  parameter integer  PIPE_INDEX = 0,
  parameter integer  DEBUG = 0
)
(
    
    input wire                  sha256_in_tvalid,
    input wire                  sha256_in_tlast,
    output wire                 sha256_in_tready,
    input wire [63:0]           sha256_in_tdata,
    input wire [7:0]            sha256_in_tkeep,

    output wire                 sha256_out_tvalid,
    output wire                 sha256_out_tlast,
    input wire                  sha256_out_tready,
    output wire [63:0]          sha256_out_tdata,
    output wire [7:0]           sha256_out_tkeep,

    // Clock and reset
    input  wire                 aclk,
    input  wire[0:0]            aresetn

);

logic                  sha256_input_fifo_tvalid;
logic                  sha256_input_fifo_tlast;
logic                  sha256_input_fifo_tready;
logic [63:0]           sha256_input_fifo_tdata;
logic [7:0]            sha256_input_fifo_tkeep;

logic                  sha256_output_fifo_tvalid;
logic                  sha256_output_fifo_tlast;
logic                  sha256_output_fifo_tready;
logic [63:0]           sha256_output_fifo_tdata;
logic [7:0]            sha256_output_fifo_tkeep;

AXI4S #(.AXI4S_DATA_BITS(512)) m_axis_converter_64_to_512();
metaIntf #(.STYPE(bft_hdr_t)) m_meta();

AXI4S #(.AXI4S_DATA_BITS(64)) sha_pipe_input();
AXI4S #(.AXI4S_DATA_BITS(64)) sha_pipe_input_reg();

AXI4S #(.AXI4S_DATA_BITS(64)) sha_pipe_output();
AXI4S #(.AXI4S_DATA_BITS(64)) sha_pipe_output_reg();

AXI4S #(.AXI4S_DATA_BITS(64)) sha256_duplicate_stream_0();
AXI4S #(.AXI4S_DATA_BITS(64)) sha256_duplicate_stream_0_reg();

AXI4S #(.AXI4S_DATA_BITS(64)) sha256_duplicate_stream_1();
AXI4S #(.AXI4S_DATA_BITS(64)) sha256_duplicate_stream_1_reg();


AXI4S #(.AXI4S_DATA_BITS(512)) axis_sha_in();
AXI4S #(.AXI4S_DATA_BITS(512)) axis_sha_in_reg();

metaIntf #(.STYPE(logic [255:0])) hash_strm_out();
metaIntf #(.STYPE(logic [255:0])) hash_strm_out_reg();

assign sha_pipe_input.tvalid = sha256_in_tvalid;
assign sha_pipe_input.tlast = sha256_in_tlast;
assign sha_pipe_input.tdata = sha256_in_tdata;
assign sha_pipe_input.tkeep = sha256_in_tkeep;
assign sha256_in_tready = sha_pipe_input.tready;

axis_reg_array #(.N_STAGES(2), .DATA_BITS(64)) inst_sha_pipe_input_array (.aclk(aclk), .aresetn(aresetn), .s_axis(sha_pipe_input), .m_axis(sha_pipe_input_reg));

// output of the sha input fifo is forwarded to both 64-to-512 converter and the output fifo
axis_data_fifo_width_64_depth_1024_no_keep_uram sha_input_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    // .s_axis_tkeep ( sha256_in_tkeep ),
    .s_axis_tlast ( sha_pipe_input_reg.tlast ),
    .s_axis_tready ( sha_pipe_input_reg.tready ),
    .s_axis_tvalid ( sha_pipe_input_reg.tvalid ),
    .s_axis_tdata ( sha_pipe_input_reg.tdata ),
    // .m_axis_tkeep ( sha256_input_fifo_tkeep ),
    .m_axis_tlast ( sha256_input_fifo_tlast ),
    .m_axis_tready ( sha256_input_fifo_tready ),
    .m_axis_tvalid ( sha256_input_fifo_tvalid ),
    .m_axis_tdata ( sha256_input_fifo_tdata )
);

assign sha256_input_fifo_tkeep = {8{1'b1}};

duplicate_stream_64_ip duplicate_stream_64 (
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .in_r_TDATA(sha256_input_fifo_tdata),
    .in_r_TVALID(sha256_input_fifo_tvalid),
    .in_r_TREADY(sha256_input_fifo_tready),
    .in_r_TKEEP(sha256_input_fifo_tkeep),
    .in_r_TSTRB(0),
    .in_r_TLAST(sha256_input_fifo_tlast),
    .out0_TDATA(sha256_duplicate_stream_0.tdata),
    .out0_TVALID(sha256_duplicate_stream_0.tvalid),
    .out0_TREADY(sha256_duplicate_stream_0.tready),
    .out0_TKEEP(sha256_duplicate_stream_0.tkeep),
    .out0_TSTRB(),
    .out0_TLAST(sha256_duplicate_stream_0.tlast),
    .out1_TDATA(sha256_duplicate_stream_1.tdata),
    .out1_TVALID(sha256_duplicate_stream_1.tvalid),
    .out1_TREADY(sha256_duplicate_stream_1.tready),
    .out1_TKEEP(sha256_duplicate_stream_1.tkeep),
    .out1_TSTRB(),
    .out1_TLAST(sha256_duplicate_stream_1.tlast)
);


// sha digest path
// convert to 512 bit
// if header length is larger than 0, the header is not forwarded to the sha module
axis_dwidth_converter_64_to_512 axis_dwidth_converter_64_to_512 (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( sha256_duplicate_stream_0.tready ),
    .m_axis_tready ( m_axis_converter_64_to_512.tready ),
    .s_axis_tvalid ( sha256_duplicate_stream_0.tvalid ),
    .s_axis_tdata ( sha256_duplicate_stream_0.tdata ),
    .s_axis_tkeep ( sha256_duplicate_stream_0.tkeep ),
    .s_axis_tlast ( sha256_duplicate_stream_0.tlast ),
    .m_axis_tvalid ( m_axis_converter_64_to_512.tvalid ),
    .m_axis_tdata ( m_axis_converter_64_to_512.tdata ),
    .m_axis_tkeep ( m_axis_converter_64_to_512.tkeep ),
    .m_axis_tlast ( m_axis_converter_64_to_512.tlast )
);


bft_depacketizer_ip bft_depacketizer_inst(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .s_axis_TREADY ( m_axis_converter_64_to_512.tready ),
    .s_axis_TVALID ( m_axis_converter_64_to_512.tvalid ),
    .s_axis_TDATA ( m_axis_converter_64_to_512.tdata ),
    .s_axis_TKEEP ( m_axis_converter_64_to_512.tkeep ),
    .s_axis_TLAST ( m_axis_converter_64_to_512.tlast ),
    .s_axis_TSTRB(0),
    .m_axis_TREADY ( axis_sha_in.tready ),
    .m_axis_TVALID ( axis_sha_in.tvalid ),
    .m_axis_TDATA ( axis_sha_in.tdata ),
    .m_axis_TKEEP ( axis_sha_in.tkeep ),
    .m_axis_TLAST ( axis_sha_in.tlast ),
    .m_meta_TVALID (m_meta.valid),
    .m_meta_TREADY (m_meta.ready),
    .m_meta_TDATA (m_meta.data)
);

assign m_meta.ready = 1'b1;


axis_reg_array #(.N_STAGES(1)) inst_axis_sha_in_reg_array (.aclk(aclk), .aresetn(aresetn), .s_axis(axis_sha_in), .m_axis(axis_sha_in_reg));

// input path 512
// output path 256
sha256_module_secworks #( 
  .DEBUG((PIPE_INDEX == 0) & (DEBUG == 1))
)sha256_module_secworks
(
    .sha256_in_tvalid(axis_sha_in_reg.tvalid),
    .sha256_in_tlast(axis_sha_in_reg.tlast),
    .sha256_in_tready(axis_sha_in_reg.tready),
    .sha256_in_tdata(axis_sha_in_reg.tdata),
    .sha256_in_tkeep(axis_sha_in_reg.tkeep),

    .sha256_out_tvalid(hash_strm_out.valid),
    .sha256_out_tready(hash_strm_out.ready),
    .sha256_out_tdata(hash_strm_out.data),
    
    // Clock and reset
    .aclk(aclk),
    .aresetn(aresetn)
);

meta_reg_array #(.N_STAGES(1), .DATA_BITS(256)) inst_hash_strm_out_reg_array (.aclk(aclk), .aresetn(aresetn), .s_meta(hash_strm_out), .m_meta(hash_strm_out_reg));

logic                  hash_strm_64_bit_tvalid;
logic                  hash_strm_64_bit_tlast;
logic                  hash_strm_64_bit_tready;
logic [63:0]           hash_strm_64_bit_tdata;
logic [7:0]            hash_strm_64_bit_tkeep;

// convert to 64 bit
axis_dwidth_converter_256_to_64 axis_dwidth_converter_256_to_64 (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( hash_strm_out_reg.ready ),
    .m_axis_tready ( hash_strm_64_bit_tready ),
    .s_axis_tvalid ( hash_strm_out_reg.valid ),
    .s_axis_tdata ( hash_strm_out_reg.data ),
    .s_axis_tkeep ( {32{1'b1}} ),
    .s_axis_tlast ( 1'b1 ),
    .m_axis_tvalid ( hash_strm_64_bit_tvalid ),
    .m_axis_tdata ( hash_strm_64_bit_tdata ),
    .m_axis_tkeep ( hash_strm_64_bit_tkeep ),
    .m_axis_tlast ( hash_strm_64_bit_tlast )
);

// duplicate stream path
axis_reg_array #(.N_STAGES(4), .DATA_BITS(64)) inst_sha256_duplicate_stream_1_reg_array (.aclk(aclk), .aresetn(aresetn), .s_axis(sha256_duplicate_stream_1), .m_axis(sha256_duplicate_stream_1_reg));

// append the hash stream to the duplicate data stream
append_stream_64_ip append_stream_64 (
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .in0_TDATA(sha256_duplicate_stream_1_reg.tdata),
    .in0_TVALID(sha256_duplicate_stream_1_reg.tvalid),
    .in0_TREADY(sha256_duplicate_stream_1_reg.tready),
    .in0_TKEEP(sha256_duplicate_stream_1_reg.tkeep),
    .in0_TSTRB(0),
    .in0_TLAST(sha256_duplicate_stream_1_reg.tlast),
    .in1_TDATA(hash_strm_64_bit_tdata),
    .in1_TVALID(hash_strm_64_bit_tvalid),
    .in1_TREADY(hash_strm_64_bit_tready),
    .in1_TKEEP(hash_strm_64_bit_tkeep),
    .in1_TSTRB(0),
    .in1_TLAST(hash_strm_64_bit_tlast),
    .out_r_TDATA(sha256_output_fifo_tdata),
    .out_r_TVALID(sha256_output_fifo_tvalid),
    .out_r_TREADY(sha256_output_fifo_tready),
    .out_r_TKEEP(sha256_output_fifo_tkeep),
    .out_r_TSTRB(),
    .out_r_TLAST(sha256_output_fifo_tlast)
);

axis_packet_fifo_width_64_depth_1024_no_keep_uram sha_output_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    // .s_axis_tkeep ( sha256_output_fifo_tkeep ),
    .s_axis_tlast ( sha256_output_fifo_tlast ),
    .s_axis_tready ( sha256_output_fifo_tready ),
    .s_axis_tvalid ( sha256_output_fifo_tvalid ),
    .s_axis_tdata ( sha256_output_fifo_tdata ),
    // .m_axis_tkeep ( sha256_out_tkeep ),
    .m_axis_tlast ( sha_pipe_output.tlast ),
    .m_axis_tready ( sha_pipe_output.tready ),
    .m_axis_tvalid ( sha_pipe_output.tvalid ),
    .m_axis_tdata ( sha_pipe_output.tdata )
);

assign sha_pipe_output.tkeep = {8{1'b1}};

axis_reg_array #(.N_STAGES(2), .DATA_BITS(64)) inst_sha_pipe_output_array (.aclk(aclk), .aresetn(aresetn), .s_axis(sha_pipe_output), .m_axis(sha_pipe_output_reg));

assign sha256_out_tvalid = sha_pipe_output_reg.tvalid;
assign sha256_out_tlast = sha_pipe_output_reg.tlast;
assign sha256_out_tdata = sha_pipe_output_reg.tdata;
assign sha256_out_tkeep = sha_pipe_output_reg.tkeep;
assign sha_pipe_output_reg.tready = sha256_out_tready;

endmodule
