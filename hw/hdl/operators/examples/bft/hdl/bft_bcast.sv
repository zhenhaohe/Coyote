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
module bft_bcast (
    AXI4S.s                     s_msg,
    
    AXI4S.m                     m_payload,
    metaIntf.m                  m_hdr,

    // Clock and reset
    input  wire                 aclk,
    input  wire[0:0]            aresetn
);

AXI4S #(.AXI4S_DATA_BITS(512)) m_payload_int();
metaIntf #(.STYPE(bft_hdr_t)) m_hdr_int();

bft_depacketizer_ip bft_depacketizer_inst(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .s_axis_tready ( s_msg.tready ),
    .s_axis_tvalid ( s_msg.tvalid ),
    .s_axis_tdata ( s_msg.tdata ),
    .s_axis_tkeep ( s_msg.tkeep ),
    .s_axis_tlast ( s_msg.tlast ),
    .m_axis_tready ( m_payload_int.tready ),
    .m_axis_tvalid ( m_payload_int.tvalid ),
    .m_axis_tdata ( m_payload_int.tdata ),
    .m_axis_tkeep ( m_payload_int.tkeep ),
    .m_axis_tlast ( m_payload_int.tlast ),
    .m_meta_tvalid (m_hdr_int.valid),
    .m_meta_tready (m_hdr_int.ready),
    .m_meta_tdata (m_hdr_int.data)
);



endmodule