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

/**
 * User logic
 * 
 */
module bft_strm_arbiter (
    // Host 
    AXI4SR.s                    s_axis,

    // Output
    AXI4S.m                     m_axis_0,
    AXI4S.m                     m_axis_1,
    AXI4S.m                     m_axis_2,
    AXI4S.m                     m_axis_3,

    // Clock and reset
    input  wire                 aclk,
    input  wire[0:0]            aresetn
);

// Multiplex the input data stream to different output
localparam integer NUM_OUTPUT_STRM = 4;
localparam integer NUM_OUTPUT_STRM_BITS = $clog2(NUM_OUTPUT_STRM);

logic [NUM_OUTPUT_STRM-1:0] m_axis_input_switch_tvalid;
logic [NUM_OUTPUT_STRM-1:0] m_axis_input_switch_tready;
logic [NUM_OUTPUT_STRM-1:0] m_axis_input_switch_tlast;
logic [NUM_OUTPUT_STRM*512-1:0] m_axis_input_switch_tdata;
logic [NUM_OUTPUT_STRM*64-1:0] m_axis_input_switch_tkeep;
logic [NUM_OUTPUT_STRM*NUM_OUTPUT_STRM_BITS-1:0] m_axis_input_switch_tdest;

axis_switch_width_512_1_to_4 axis_switch_width_512_1_to_4_inst (
	.aclk ( aclk ),
	.aresetn ( aresetn ),
	.s_axis_tready ( s_axis.tready ),
	.m_axis_tready ( m_axis_input_switch_tready ),
	.s_axis_tvalid ( s_axis.tvalid ),
	.s_axis_tdata ( s_axis.tdata ),
	.s_axis_tkeep ( s_axis.tkeep ),
	.s_axis_tlast ( s_axis.tlast ),
	.s_axis_tdest ( s_axis.tdest ),
	.m_axis_tvalid ( m_axis_input_switch_tvalid ),
	.m_axis_tdata ( m_axis_input_switch_tdata ),
	.m_axis_tkeep ( m_axis_input_switch_tkeep ),
	.m_axis_tlast ( m_axis_input_switch_tlast ),
	.m_axis_tdest ( m_axis_input_switch_tdest ),
	.s_decode_err ( )
);

assign m_axis_0.tvalid = m_axis_input_switch_tvalid[0];
assign m_axis_0.tlast = m_axis_input_switch_tlast[0];
assign m_axis_input_switch_tready[0] = m_axis_0.tready;
assign m_axis_0.tdata = m_axis_input_switch_tdata[(0+1)*512-1:0*512];
assign m_axis_0.tkeep = m_axis_input_switch_tkeep[(0+1)*64-1:0*64];


assign m_axis_1.tvalid = m_axis_input_switch_tvalid[1];
assign m_axis_1.tlast = m_axis_input_switch_tlast[1];
assign m_axis_input_switch_tready[1] = m_axis_1.tready;
assign m_axis_1.tdata = m_axis_input_switch_tdata[(1+1)*512-1:1*512];
assign m_axis_1.tkeep = m_axis_input_switch_tkeep[(1+1)*64-1:1*64];

assign m_axis_2.tvalid = m_axis_input_switch_tvalid[2];
assign m_axis_2.tlast = m_axis_input_switch_tlast[2];
assign m_axis_input_switch_tready[2] = m_axis_2.tready;
assign m_axis_2.tdata = m_axis_input_switch_tdata[(2+1)*512-1:2*512];
assign m_axis_2.tkeep = m_axis_input_switch_tkeep[(2+1)*64-1:2*64];

assign m_axis_3.tvalid = m_axis_input_switch_tvalid[3];
assign m_axis_3.tlast = m_axis_input_switch_tlast[3];
assign m_axis_input_switch_tready[3] = m_axis_3.tready;
assign m_axis_3.tdata = m_axis_input_switch_tdata[(3+1)*512-1:3*512];
assign m_axis_3.tkeep = m_axis_input_switch_tkeep[(3+1)*64-1:3*64];


endmodule