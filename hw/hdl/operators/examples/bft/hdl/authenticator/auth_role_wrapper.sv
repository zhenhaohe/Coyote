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
module auth_role_wrapper #( 
  parameter integer NUM_ENGINE = 4,
  parameter integer VERIFICATION = 0
)(
    AXI4S.s                     s_axis,
    metaIntf.s                  s_meta,

    AXI4S.m                     m_axis,
    metaIntf.m                  m_meta,

    // Clock and reset
    input  wire                 aclk,
    input  wire[0:0]            aresetn
);

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) auth_in_s0();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) auth_in_s1();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) auth_out_s0();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) auth_out_s1();


bft_packetizer_ip bft_auth_packetizer_inst(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .s_axis_TREADY ( s_axis.tready ),
    .s_axis_TVALID ( s_axis.tvalid ),
    .s_axis_TDATA ( s_axis.tdata ),
    .s_axis_TKEEP ( s_axis.tkeep ),
    .s_axis_TLAST ( s_axis.tlast ),
    .s_axis_TSTRB (0),
    .s_meta_TVALID (s_meta.valid),
    .s_meta_TREADY (s_meta.ready),
    .s_meta_TDATA (s_meta.data),
    .m_axis_TREADY ( auth_in_s0.tready ),
    .m_axis_TVALID ( auth_in_s0.tvalid ),
    .m_axis_TDATA ( auth_in_s0.tdata ),
    .m_axis_TKEEP ( auth_in_s0.tkeep ),
    .m_axis_TLAST ( auth_in_s0.tlast )
);

axis_reg_array #(.N_STAGES(3)) inst_auth_in (.aclk(aclk), .aresetn(aresetn), .s_axis(auth_in_s0), .m_axis(auth_in_s1));

auth_role #( 
  .NUM_ENGINE(NUM_ENGINE),
  .VERIFICATION(VERIFICATION)
) auth_role
(
    
    .num_engine(NUM_ENGINE),

    .auth_in_tvalid(auth_in_s1.tvalid),
    .auth_in_tlast(auth_in_s1.tlast),
    .auth_in_tready(auth_in_s1.tready),
    .auth_in_tdata(auth_in_s1.tdata),
    .auth_in_tkeep(auth_in_s1.tkeep),

    .auth_out_tvalid(auth_out_s0.tvalid),
    .auth_out_tlast(auth_out_s0.tlast),
    .auth_out_tready(auth_out_s0.tready),
    .auth_out_tdata(auth_out_s0.tdata),
    .auth_out_tkeep(auth_out_s0.tkeep),

    // Clock and reset
    .aclk(aclk),
    .aresetn(aresetn)
);

axis_reg_array #(.N_STAGES(3)) inst_auth_out (.aclk(aclk), .aresetn(aresetn), .s_axis(auth_out_s0), .m_axis(auth_out_s1));

bft_depacketizer_ip bft_auth_depacketizer (
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .s_axis_TREADY ( auth_out_s1.tready ),
    .s_axis_TVALID ( auth_out_s1.tvalid ),
    .s_axis_TDATA ( auth_out_s1.tdata ),
    .s_axis_TKEEP ( auth_out_s1.tkeep ),
    .s_axis_TLAST ( auth_out_s1.tlast ),
    .s_axis_TSTRB (0),
    .m_axis_TREADY ( m_axis.tready ),
    .m_axis_TVALID ( m_axis.tvalid ),
    .m_axis_TDATA ( m_axis.tdata ),
    .m_axis_TKEEP ( m_axis.tkeep ),
    .m_axis_TLAST ( m_axis.tlast ),
    .m_meta_TVALID (m_meta.valid),
    .m_meta_TREADY (m_meta.ready),
    .m_meta_TDATA (m_meta.data)
);


endmodule