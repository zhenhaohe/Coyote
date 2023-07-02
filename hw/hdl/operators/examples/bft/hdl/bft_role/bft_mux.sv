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
module bft_mux (
    AXI4S.s                     s_axis_0,
    metaIntf.s                  s_meta_0,
    AXI4S.s                     s_axis_1,
    metaIntf.s                  s_meta_1,

    AXI4S.m                     m_axis,
    metaIntf.m                  m_meta,

    // Clock and reset
    input  wire                 aclk,
    input  wire[0:0]            aresetn
);


bft_mux_ip bft_mux_inst(
    .s_meta_0_TDATA(s_meta_0.data),
    .s_meta_0_TVALID(s_meta_0.valid),
    .s_meta_0_TREADY(s_meta_0.ready),

    .s_axis_0_TDATA(s_axis_0.tdata),
    .s_axis_0_TKEEP(s_axis_0.tkeep),
    .s_axis_0_TSTRB(0),
    .s_axis_0_TLAST(s_axis_0.tlast),
    .s_axis_0_TVALID(s_axis_0.tvalid),
    .s_axis_0_TREADY(s_axis_0.tready),

    .s_meta_1_TDATA(s_meta_1.data),
    .s_meta_1_TVALID(s_meta_1.valid),
    .s_meta_1_TREADY(s_meta_1.ready),

    .s_axis_1_TDATA(s_axis_1.tdata),
    .s_axis_1_TKEEP(s_axis_1.tkeep),
    .s_axis_1_TSTRB(0),
    .s_axis_1_TLAST(s_axis_1.tlast),
    .s_axis_1_TVALID(s_axis_1.tvalid),
    .s_axis_1_TREADY(s_axis_1.tready),

    .m_meta_TDATA(m_meta.data),
    .m_meta_TVALID(m_meta.valid),
    .m_meta_TREADY(m_meta.ready),

    .m_axis_TDATA(m_axis.tdata),
    .m_axis_TKEEP(m_axis.tkeep),
    .m_axis_TSTRB(),
    .m_axis_TLAST(m_axis.tlast),
    .m_axis_TVALID(m_axis.tvalid),
    .m_axis_TREADY(m_axis.tready),

    .ap_clk(aclk),
    .ap_rst_n(aresetn)
);



endmodule
