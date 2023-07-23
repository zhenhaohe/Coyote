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
module bft_arbiter (
    // Input 
    AXI4S.s                     s_axis,
    metaIntf.s                  s_meta,

    // Output
    AXI4S.m                     m_axis_0,
    metaIntf.m                  m_meta_0,
    AXI4S.m                     m_axis_1,
    metaIntf.m                  m_meta_1,

    // Clock and reset
    input  wire                 aclk,
    input  wire[0:0]            aresetn
);

bft_arbiter_ip bft_arbiter_inst(
    .s_meta_TDATA(s_meta.data),
    .s_meta_TVALID(s_meta.valid),
    .s_meta_TREADY(s_meta.ready),

    .s_axis_TDATA(s_axis.tdata),
    .s_axis_TKEEP(s_axis.tkeep),
    .s_axis_TSTRB(0),
    .s_axis_TLAST(s_axis.tlast),
    .s_axis_TVALID(s_axis.tvalid),
    .s_axis_TREADY(s_axis.tready),

    .m_meta_0_TDATA(m_meta_0.data),
    .m_meta_0_TVALID(m_meta_0.valid),
    .m_meta_0_TREADY(m_meta_0.ready),

    .m_axis_0_TDATA(m_axis_0.tdata),
    .m_axis_0_TKEEP(m_axis_0.tkeep),
    .m_axis_0_TSTRB(),
    .m_axis_0_TLAST(m_axis_0.tlast),
    .m_axis_0_TVALID(m_axis_0.tvalid),
    .m_axis_0_TREADY(m_axis_0.tready),

    .m_meta_1_TDATA(m_meta_1.data),
    .m_meta_1_TVALID(m_meta_1.valid),
    .m_meta_1_TREADY(m_meta_1.ready),

    .m_axis_1_TDATA(m_axis_1.tdata),
    .m_axis_1_TKEEP(m_axis_1.tkeep),
    .m_axis_1_TSTRB(),
    .m_axis_1_TLAST(m_axis_1.tlast),
    .m_axis_1_TVALID(m_axis_1.tvalid),
    .m_axis_1_TREADY(m_axis_1.tready),

    .ap_clk(aclk),
    .ap_rst_n(aresetn)
);

endmodule