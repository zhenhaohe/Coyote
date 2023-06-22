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
module bench_role (
    // Control
    AXI4L.s                     s_axi_ctrl,

    AXI4S.m                     netTxData,
    metaIntf.m                  netTxMeta,
    AXI4S.s                     netRxData,
    metaIntf.s                  netRxMeta,

    // Host 
    AXI4S.m                     hostTxData,
    metaIntf.m                  hostTxMeta,
    AXI4SR.s                    hostRxData,

    // Clock and reset
    input  wire                 aclk,
    input  wire[0:0]            aresetn
);

always_comb netTxData.tie_off_m();
always_comb netTxMeta.tie_off_m();
always_comb netRxData.tie_off_s();
always_comb netRxMeta.tie_off_s();

always_comb hostTxData.tie_off_m();
always_comb hostTxMeta.tie_off_m();

always_comb s_axi_ctrl.tie_off_s();

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) comm_strm();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) comm_strm_reg();

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) msg_strm();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) msg_strm_reg();

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) authkey_strm();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) authkey_strm_reg();

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) verifkey_strm();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) verifkey_strm_reg();

// Multiplex the host input data stream to communicator, bft, auth key and verif key
bft_strm_arbiter bft_strm_arbiter(
    .s_axis(hostRxData),

    .m_axis_0(comm_strm),
    .m_axis_1(msg_strm),
    .m_axis_2(authkey_strm),
    .m_axis_3(verifkey_strm),

    .aclk(aclk),
    .aresetn(aresetn)
);

axis_reg_array #(.N_STAGES(2)) inst_comm_strm_reg_array (.aclk(aclk), .aresetn(aresetn), .s_axis(comm_strm), .m_axis(comm_strm_reg));
axis_reg_array #(.N_STAGES(2)) inst_msg_strm_reg_array (.aclk(aclk), .aresetn(aresetn), .s_axis(msg_strm), .m_axis(msg_strm_reg));
axis_reg_array #(.N_STAGES(2)) inst_authkey_strm_reg_array (.aclk(aclk), .aresetn(aresetn), .s_axis(authkey_strm), .m_axis(authkey_strm_reg));
axis_reg_array #(.N_STAGES(2)) inst_verifkey_strm_reg_array (.aclk(aclk), .aresetn(aresetn), .s_axis(verifkey_strm), .m_axis(verifkey_strm_reg));


// bft tx data path

AXI4S #(.AXI4S_DATA_BITS(512)) m_payload_int_0();
metaIntf #(.STYPE(bft_hdr_t)) m_hdr_int_0();

AXI4S #(.AXI4S_DATA_BITS(512)) m_payload_int_1();
metaIntf #(.STYPE(bft_hdr_t)) m_hdr_int_1();


bft_depacketizer_ip bft_depacketizer_inst(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .s_axis_tready ( msg_strm_reg.tready ),
    .s_axis_tvalid ( msg_strm_reg.tvalid ),
    .s_axis_tdata ( msg_strm_reg.tdata ),
    .s_axis_tkeep ( msg_strm_reg.tkeep ),
    .s_axis_tlast ( msg_strm_reg.tlast ),
    .m_axis_tready ( m_payload_int_0.tready ),
    .m_axis_tvalid ( m_payload_int_0.tvalid ),
    .m_axis_tdata ( m_payload_int_0.tdata ),
    .m_axis_tkeep ( m_payload_int_0.tkeep ),
    .m_axis_tlast ( m_payload_int_0.tlast ),
    .m_meta_tvalid (m_hdr_int_0.valid),
    .m_meta_tready (m_hdr_int_0.ready),
    .m_meta_tdata (m_hdr_int_0.data)
);

bft_bcast_ip bft_bcast_inst(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .s_meta_tvalid (m_hdr_int_0.valid),
    .s_meta_tready (m_hdr_int_0.ready),
    .s_meta_tdata (m_hdr_int_0.data)
    .s_axis_tready ( m_payload_int_0.tready ),
    .s_axis_tvalid ( m_payload_int_0.tvalid ),
    .s_axis_tdata ( m_payload_int_0.tdata ),
    .s_axis_tkeep ( m_payload_int_0.tkeep ),
    .s_axis_tlast ( m_payload_int_0.tlast ),
    .m_axis_tready ( m_payload_int_1.tready ),
    .m_axis_tvalid ( m_payload_int_1.tvalid ),
    .m_axis_tdata ( m_payload_int_1.tdata ),
    .m_axis_tkeep ( m_payload_int_1.tkeep ),
    .m_axis_tlast ( m_payload_int_1.tlast ),
    .m_meta_tvalid (m_hdr_int_1.valid),
    .m_meta_tready (m_hdr_int_1.ready),
    .m_meta_tdata (m_hdr_int_1.data),
    .totalRank(totalRank)
);











endmodule