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

import lynxTypes::*;
import bftTypes::*;

`include "lynx_macros.svh"
`include "axi_macros.svh"

// Wrapper function of auth hmac
module auth_hmac_wrapper 
#( 
    parameter integer PIPE_INDEX = 0
)
(
    // msg
    AXI4S.s                         s_msg, // 32 bits
    AXI4S.m                         m_msg, // 32 bits

    // hash
    metaIntf.m                      m_hsh, // 256 bits

    // meta
    metaIntf.s                      s_meta, // 64 bits dest:[31:0] len:[63:32]

    // Clock and reset
    input  wire                     aclk,
    input  wire[0:0]                aresetn

);

AXI4S #(.AXI4S_DATA_BITS(32)) s_msg_s0();
AXI4S #(.AXI4S_DATA_BITS(32)) s_msg_s1();

metaIntf #(.STYPE(logic[64-1:0])) s_meta_s0();
metaIntf #(.STYPE(logic[64-1:0])) s_meta_s1();
metaIntf #(.STYPE(logic[64-1:0])) s_meta_s2();

metaIntf #(.STYPE(logic[32-1:0])) key_lookup();
metaIntf #(.STYPE(logic[32-1:0])) key_lookup_resp();

metaIntf #(.STYPE(logic[64-1:0])) len_strm();

metaIntf #(.STYPE(logic[32-1:0])) msg_meta_s0();

// replicate the msg strm
duplicate_stream_32_ip duplicate_stream_32_inst(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .in_r_TDATA(s_msg.tdata),
    .in_r_TVALID(s_msg.tvalid),
    .in_r_TREADY(s_msg.tready),
    .in_r_TKEEP(s_msg.tkeep),
    .in_r_TLAST(s_msg.tlast),
    .in_r_TSTRB(0),
    .out0_TDATA(s_msg_s0.tdata),
    .out0_TVALID(s_msg_s0.tvalid),
    .out0_TREADY(s_msg_s0.tready),
    .out0_TKEEP(s_msg_s0.tkeep),
    .out0_TLAST(s_msg_s0.tlast),
    .out1_TDATA(s_msg_s1.tdata),
    .out1_TVALID(s_msg_s1.tvalid),
    .out1_TREADY(s_msg_s1.tready),
    .out1_TKEEP(s_msg_s1.tkeep),
    .out1_TLAST(s_msg_s1.tlast)
);

assign msg_meta_s0.valid = s_msg_s0.tvalid;
assign msg_meta_s0.data = s_msg_s0.tdata;
assign s_msg_s0.tready = msg_meta_s0.ready;

// replicate the meta for dest and len
duplicate_meta_64_ip duplicate_meta_64_inst(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .in_r_TDATA(s_meta.data),
    .in_r_TVALID(s_meta.valid),
    .in_r_TREADY(s_meta.ready),
    .out0_TDATA(s_meta_s0.data),
    .out0_TVALID(s_meta_s0.valid),
    .out0_TREADY(s_meta_s0.ready),
    .out1_TDATA(s_meta_s1.data),
    .out1_TVALID(s_meta_s1.valid),
    .out1_TREADY(s_meta_s1.ready)
);

axis_meta_fifo_width_32_depth_16 key_lookup_fifo_inst(
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( s_meta_s0.ready ),
    .m_axis_tready ( key_lookup.ready ),
    .s_axis_tvalid ( s_meta_s0.valid ),
    .s_axis_tdata ( s_meta_s0.data[31:0] ),
    .m_axis_tvalid ( key_lookup.valid ),
    .m_axis_tdata ( key_lookup.data )
);

axis_meta_fifo_width_32_depth_16 len_fifo_inst(
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( s_meta_s1.ready ),
    .m_axis_tready ( s_meta_s2.ready ),
    .s_axis_tvalid ( s_meta_s1.valid ),
    .s_axis_tdata ( s_meta_s1.data[63:32] ),
    .m_axis_tvalid ( s_meta_s2.valid ),
    .m_axis_tdata ( s_meta_s2.data )
);

assign len_strm.valid = s_meta_s2.valid;
assign len_strm.data = {{32{1'b0}}, s_meta_s2.data}; 
assign s_meta_s2.ready = len_strm.ready;


auth_hmac #( 
    .PIPE_INDEX(PIPE_INDEX)
) auth_hmac
(
    .keyStrm(key_lookup_resp), //32 bits
    .msgStrm(msg_meta_s0), //32 bits
    .lenStrm(len_strm), //64 bits
    .hshStrm(m_hsh), //256 bits
    .aclk(aclk),
    .aresetn(aresetn)
);


auth_key_handler_ip auth_key_handler_inst(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .key_resp_out_TDATA(key_lookup_resp.data),
    .key_resp_out_TVALID(key_lookup_resp.valid),
    .key_resp_out_TREADY(key_lookup_resp.ready),
    .key_lookup_in_TDATA(key_lookup.data),
    .key_lookup_in_TVALID(key_lookup.valid),
    .key_lookup_in_TREADY(key_lookup.ready)
);

`AXIS_ASSIGN(s_msg_s1, m_msg)

endmodule
