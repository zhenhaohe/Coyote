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


metaIntf #(.STYPE(64)) comm_meta_s0();
metaIntf #(.STYPE(64)) comm_meta_s1();

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) tx_msg_strm_s0();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) tx_msg_strm_s1();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) tx_msg_strm_s2();

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) tx_payload_s0();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) tx_payload_s1();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) tx_payload_s2();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) tx_payload_s3();

metaIntf #(.STYPE(bft_hdr_t)) tx_hdr_s0();
metaIntf #(.STYPE(bft_hdr_t)) tx_hdr_s1();
metaIntf #(.STYPE(bft_hdr_t)) tx_hdr_s2();
metaIntf #(.STYPE(bft_hdr_t)) tx_hdr_s3();

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) tx_payload_net_s0();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) tx_payload_net_s1();

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) tx_payload_crypt_s0();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) tx_payload_crypt_s1();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) tx_payload_crypt_s2();

metaIntf #(.STYPE(bft_hdr_t)) tx_hdr_net_s0();
metaIntf #(.STYPE(bft_hdr_t)) tx_hdr_net_s1();

metaIntf #(.STYPE(bft_hdr_t)) tx_hdr_crypt_s0();
metaIntf #(.STYPE(bft_hdr_t)) tx_hdr_crypt_s1();
metaIntf #(.STYPE(bft_hdr_t)) tx_hdr_crypt_s2();

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) tx_net_msg_s0();
metaIntf #(.STYPE(logic[64-1:0])) tx_net_meta_s0();

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) rx_net_msg_s0();
metaIntf #(.STYPE(logic[64-1:0])) rx_net_meta_s0();

AXI4S #(.AXI4S_DATA_BITS(512)) rx_payload_s0();
AXI4S #(.AXI4S_DATA_BITS(512)) rx_payload_s1();
AXI4S #(.AXI4S_DATA_BITS(512)) rx_payload_s2();

metaIntf #(.STYPE(bft_hdr_t)) rx_hdr_s0();
metaIntf #(.STYPE(bft_hdr_t)) rx_hdr_s1();
metaIntf #(.STYPE(bft_hdr_t)) rx_hdr_s2();

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) rx_payload_net_s0();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) rx_payload_net_s1();

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) rx_payload_crypt_s0();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) rx_payload_crypt_s1();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) rx_payload_crypt_s2();

metaIntf #(.STYPE(bft_hdr_t)) rx_hdr_net_s0();
metaIntf #(.STYPE(bft_hdr_t)) rx_hdr_net_s1();

metaIntf #(.STYPE(bft_hdr_t)) rx_hdr_crypt_s0();
metaIntf #(.STYPE(bft_hdr_t)) rx_hdr_crypt_s1();
metaIntf #(.STYPE(bft_hdr_t)) rx_hdr_crypt_s2();


AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) rx_msg_strm_s0();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) rx_msg_strm_s1();

bft_tx_stat_t bft_tx_stat_s0;
bft_tx_stat_t bft_tx_stat_s1;
bft_rx_stat_t bft_rx_stat_s0;
bft_rx_stat_t bft_rx_stat_s1;

logic ap_start, ap_start_pulse, ap_done;

logic [63:0] exp_tx_net_pkt, exp_rx_net_pkt, execution_cycles;

logic [63:0] tx_net_pkt, rx_net_pkt;

bench_role_slave bench_role_slave(
	.aclk(aclk),
	.aresetn(aresetn),
	.axi_ctrl(s_axi_ctrl),
	.ap_start(ap_start),
    .ap_done(ap_done),
    .comm_meta (comm_meta_s0),
    .bft_tx_stat(bft_tx_stat_s1),
    .bft_rx_stat(bft_rx_stat_s1),
    .exp_tx_net_pkt(exp_tx_net_pkt),
	.exp_rx_net_pkt(exp_rx_net_pkt),
    .execution_cycles(execution_cycles)
);

// convert AXI4SR to AXI4S
assign tx_msg_strm_s0.tvalid = hostRxData.tvalid;
assign tx_msg_strm_s0.tlast = hostRxData.tlast;
assign tx_msg_strm_s0.tdata = hostRxData.tdata;
assign tx_msg_strm_s0.tkeep = hostRxData.tkeep;
assign hostRxData.tready = tx_msg_strm_s0.tready;

meta_reg_array #(.N_STAGES(2), .DATA_BITS(64)) inst_comm_meta_array (.aclk(aclk), .aresetn(aresetn), .s_meta(comm_meta_s0), .m_meta(comm_meta_s1));
axis_reg_array #(.N_STAGES(2)) inst_tx_msg_strm_array (.aclk(aclk), .aresetn(aresetn), .s_axis(tx_msg_strm_s0), .m_axis(tx_msg_strm_s1));


// bft tx data path

bft_depacketizer_ip bft_tx_depacketizer_inst(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .s_axis_TREADY ( tx_msg_strm_s1.tready ),
    .s_axis_TVALID ( tx_msg_strm_s1.tvalid ),
    .s_axis_TDATA ( tx_msg_strm_s1.tdata ),
    .s_axis_TKEEP ( tx_msg_strm_s1.tkeep ),
    .s_axis_TLAST ( tx_msg_strm_s1.tlast ),
    .s_axis_TSTRB (0),
    .m_axis_TREADY ( tx_payload_s0.tready ),
    .m_axis_TVALID ( tx_payload_s0.tvalid ),
    .m_axis_TDATA ( tx_payload_s0.tdata ),
    .m_axis_TKEEP ( tx_payload_s0.tkeep ),
    .m_axis_TLAST ( tx_payload_s0.tlast ),
    .m_meta_TVALID (tx_hdr_s0.valid),
    .m_meta_TREADY (tx_hdr_s0.ready),
    .m_meta_TDATA (tx_hdr_s0.data)
);

bft_bcast_ip bft_bcast_inst(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .s_meta_TVALID (tx_hdr_s0.valid),
    .s_meta_TREADY (tx_hdr_s0.ready),
    .s_meta_TDATA (tx_hdr_s0.data),
    .s_axis_TREADY ( tx_payload_s0.tready ),
    .s_axis_TVALID ( tx_payload_s0.tvalid ),
    .s_axis_TDATA ( tx_payload_s0.tdata ),
    .s_axis_TKEEP ( tx_payload_s0.tkeep ),
    .s_axis_TLAST ( tx_payload_s0.tlast ),
    .s_axis_TSTRB (0),
    .m_axis_TREADY ( tx_payload_s1.tready ),
    .m_axis_TVALID ( tx_payload_s1.tvalid ),
    .m_axis_TDATA ( tx_payload_s1.tdata ),
    .m_axis_TKEEP ( tx_payload_s1.tkeep ),
    .m_axis_TLAST ( tx_payload_s1.tlast ),
    .m_meta_TVALID (tx_hdr_s1.valid),
    .m_meta_TREADY (tx_hdr_s1.ready),
    .m_meta_TDATA (tx_hdr_s1.data)
);

axis_reg_array #(.N_STAGES(2)) inst_tx_payload_array (.aclk(aclk), .aresetn(aresetn), .s_axis(tx_payload_s1), .m_axis(tx_payload_s2));
meta_reg_array #(.N_STAGES(2), .DATA_BITS($bits(bft_hdr_t))) inst_tx_hdr_array (.aclk(aclk), .aresetn(aresetn), .s_meta(tx_hdr_s1), .m_meta(tx_hdr_s2));

bft_arbiter bft_tx_arbiter(
    .s_axis(tx_payload_s2),
    .s_meta(tx_hdr_s2),
    .m_axis_0(tx_payload_net_s0),
    .m_meta_0(tx_hdr_net_s0),
    .m_axis_1(tx_payload_crypt_s0),
    .m_meta_1(tx_hdr_crypt_s0),
    .aclk(aclk),
    .aresetn(aresetn)
);

// Network Offload Path

axis_reg_array_profiler #(.N_STAGES(2), .DATA_BITS(AXI_DATA_BITS)) inst_axis_tx_payload_net_array (
    .aclk(aclk), 
    .aresetn(aresetn), 
    .reset(ap_start_pulse),
    .s_axis(tx_payload_net_s0), 
    .m_axis(tx_payload_net_s1), 
    .byte_cnt(bft_tx_stat_s0.net_offload_bytes), 
    .pkt_cnt(bft_tx_stat_s0.net_offload_pkt), 
    .ready_down(bft_tx_stat_s0.net_offload_down)
);

meta_reg_array #(.N_STAGES(2), .DATA_BITS($bits(bft_hdr_t))) inst_tx_hdr_net_array (.aclk(aclk), .aresetn(aresetn), .s_meta(tx_hdr_net_s0), .m_meta(tx_hdr_net_s1));

// Crypto Offload Path

axis_reg_array_profiler #(.N_STAGES(2), .DATA_BITS(AXI_DATA_BITS)) inst_axis_tx_payload_auth_array (
    .aclk(aclk), 
    .aresetn(aresetn), 
    .reset(ap_start_pulse),
    .s_axis(tx_payload_crypt_s0), 
    .m_axis(tx_payload_crypt_s1), 
    .byte_cnt(bft_tx_stat_s0.auth_offload_bytes), 
    .pkt_cnt(bft_tx_stat_s0.auth_offload_pkt), 
    .ready_down(bft_tx_stat_s0.auth_offload_down)
);

meta_reg_array #(.N_STAGES(2), .DATA_BITS($bits(bft_hdr_t))) inst_tx_hdr_auth_array (.aclk(aclk), .aresetn(aresetn), .s_meta(tx_hdr_crypt_s0), .m_meta(tx_hdr_crypt_s1));

auth_role_wrapper #(.NUM_ENGINE(NUM_AUTH_TX), .VERIFICATION(0))
auth_role_wrapper_tx(
    .s_axis(tx_payload_crypt_s1),
    .s_meta(tx_hdr_crypt_s1),
    .m_axis(tx_payload_crypt_s2),
    .m_meta(tx_hdr_crypt_s2),
    .aclk(aclk),
    .aresetn(aresetn)
);


bft_mux bft_tx_mux(
    .s_axis_0(tx_payload_net_s1),
    .s_meta_0(tx_hdr_net_s1),
    .s_axis_1(tx_payload_crypt_s2),
    .s_meta_1(tx_hdr_crypt_s2),
    .m_axis(tx_payload_s3),
    .m_meta(tx_hdr_s3),
    .aclk(aclk),
    .aresetn(aresetn)
);


bft_packetizer_ip bft_tx_packetizer_inst(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .s_axis_TREADY ( tx_payload_s3.tready ),
    .s_axis_TVALID ( tx_payload_s3.tvalid ),
    .s_axis_TDATA ( tx_payload_s3.tdata ),
    .s_axis_TKEEP ( tx_payload_s3.tkeep ),
    .s_axis_TLAST ( tx_payload_s3.tlast ),
    .s_axis_TSTRB (0),
    .s_meta_TVALID (tx_hdr_s3.valid),
    .s_meta_TREADY (tx_hdr_s3.ready),
    .s_meta_TDATA (tx_hdr_s3.data),
    .m_axis_TREADY ( tx_msg_strm_s2.tready ),
    .m_axis_TVALID ( tx_msg_strm_s2.tvalid ),
    .m_axis_TDATA ( tx_msg_strm_s2.tdata ),
    .m_axis_TKEEP ( tx_msg_strm_s2.tkeep ),
    .m_axis_TLAST ( tx_msg_strm_s2.tlast )
);

bft_meta_gen_ip tx_net_meta_gen_inst (
    .s_axis_TREADY ( tx_msg_strm_s2.tready ),
    .s_axis_TVALID ( tx_msg_strm_s2.tvalid ),
    .s_axis_TDATA ( tx_msg_strm_s2.tdata ),
    .s_axis_TKEEP ( tx_msg_strm_s2.tkeep ),
    .s_axis_TLAST ( tx_msg_strm_s2.tlast ),
    .s_axis_TSTRB (0),
    .m_meta_TVALID (tx_net_meta_s0.valid),
    .m_meta_TREADY (tx_net_meta_s0.ready),
    .m_meta_TDATA (tx_net_meta_s0.data),
    .m_axis_TREADY ( tx_net_msg_s0.tready ),
    .m_axis_TVALID ( tx_net_msg_s0.tvalid ),
    .m_axis_TDATA ( tx_net_msg_s0.tdata ),
    .m_axis_TKEEP ( tx_net_msg_s0.tkeep ),
    .m_axis_TLAST ( tx_net_msg_s0.tlast ),
    .ap_clk(aclk),
    .ap_rst_n(aresetn)
);


ccl_engine ccl_engine
(
    .tx_data_in(tx_net_msg_s0),
    .tx_meta_in(tx_net_meta_s0),
    .net_tx_data_out(netTxData),
    .net_tx_meta_out(netTxMeta),
    .net_rx_data_in(netRxData),
    .net_rx_meta_in(netRxMeta),
    .rx_data_out(rx_net_msg_s0),
    .rx_meta_out(rx_net_meta_s0),
    .configComm_in(comm_meta_s1),
    .aclk(aclk),
    .aresetn(aresetn)

);

// bft rx data path

assign rx_net_meta_s0.ready = 1'b1;

bft_depacketizer_ip bft_rx_depacketizer (
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .s_axis_TREADY ( rx_net_msg_s0.tready ),
    .s_axis_TVALID ( rx_net_msg_s0.tvalid ),
    .s_axis_TDATA ( rx_net_msg_s0.tdata ),
    .s_axis_TKEEP ( rx_net_msg_s0.tkeep ),
    .s_axis_TLAST ( rx_net_msg_s0.tlast ),
    .s_axis_TSTRB (0),
    .m_axis_TREADY ( rx_payload_s0.tready ),
    .m_axis_TVALID ( rx_payload_s0.tvalid ),
    .m_axis_TDATA ( rx_payload_s0.tdata ),
    .m_axis_TKEEP ( rx_payload_s0.tkeep ),
    .m_axis_TLAST ( rx_payload_s0.tlast ),
    .m_meta_TVALID (rx_hdr_s0.valid),
    .m_meta_TREADY (rx_hdr_s0.ready),
    .m_meta_TDATA (rx_hdr_s0.data)
);

axis_reg_array #(.N_STAGES(3)) inst_rx_payload_array (.aclk(aclk), .aresetn(aresetn), .s_axis(rx_payload_s0), .m_axis(rx_payload_s1));
meta_reg_array #(.N_STAGES(3), .DATA_BITS($bits(bft_hdr_t))) inst_rx_hdr_array (.aclk(aclk), .aresetn(aresetn), .s_meta(rx_hdr_s0), .m_meta(rx_hdr_s1));


bft_arbiter bft_rx_arbiter(
    .s_axis(rx_payload_s1),
    .s_meta(rx_hdr_s1),
    .m_axis_0(rx_payload_net_s0),
    .m_meta_0(rx_hdr_net_s0),
    .m_axis_1(rx_payload_crypt_s0),
    .m_meta_1(rx_hdr_crypt_s0),
    .aclk(aclk),
    .aresetn(aresetn)
);

// Network Offload Path

axis_reg_array_profiler #(.N_STAGES(2), .DATA_BITS(AXI_DATA_BITS)) inst_axis_rx_payload_net_array (
    .aclk(aclk), 
    .aresetn(aresetn), 
    .reset(ap_start_pulse),
    .s_axis(rx_payload_net_s0), 
    .m_axis(rx_payload_net_s1), 
    .byte_cnt(bft_rx_stat_s0.net_offload_bytes), 
    .pkt_cnt(bft_rx_stat_s0.net_offload_pkt), 
    .ready_down(bft_rx_stat_s0.net_offload_down)
);

meta_reg_array #(.N_STAGES(2), .DATA_BITS($bits(bft_hdr_t))) inst_rx_hdr_net_array (.aclk(aclk), .aresetn(aresetn), .s_meta(rx_hdr_net_s0), .m_meta(rx_hdr_net_s1));

// Crypto Offload Path

axis_reg_array_profiler #(.N_STAGES(2), .DATA_BITS(AXI_DATA_BITS)) inst_axis_rx_payload_auth_array (
    .aclk(aclk), 
    .aresetn(aresetn), 
    .reset(ap_start_pulse),
    .s_axis(rx_payload_crypt_s0), 
    .m_axis(rx_payload_crypt_s1), 
    .byte_cnt(bft_rx_stat_s0.auth_offload_bytes), 
    .pkt_cnt(bft_rx_stat_s0.auth_offload_pkt), 
    .ready_down(bft_rx_stat_s0.auth_offload_down)
);

meta_reg_array #(.N_STAGES(2), .DATA_BITS($bits(bft_hdr_t))) inst_rx_hdr_auth_array (.aclk(aclk), .aresetn(aresetn), .s_meta(rx_hdr_crypt_s0), .m_meta(rx_hdr_crypt_s1));

auth_role_wrapper #(.NUM_ENGINE(NUM_AUTH_RX), .VERIFICATION(1))
auth_role_wrapper_rx(
    .s_axis(rx_payload_crypt_s1),
    .s_meta(rx_hdr_crypt_s1),
    .m_axis(rx_payload_crypt_s2),
    .m_meta(rx_hdr_crypt_s2),
    .aclk(aclk),
    .aresetn(aresetn)
);

bft_mux bft_rx_mux(
    .s_axis_0(rx_payload_net_s1),
    .s_meta_0(rx_hdr_net_s1),
    .s_axis_1(rx_payload_crypt_s2),
    .s_meta_1(rx_hdr_crypt_s2),
    .m_axis(rx_payload_s2),
    .m_meta(rx_hdr_s2),
    .aclk(aclk),
    .aresetn(aresetn)
);

bft_packetizer_ip bft_rx_packetizer_inst(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .s_axis_TREADY ( rx_payload_s2.tready ),
    .s_axis_TVALID ( rx_payload_s2.tvalid ),
    .s_axis_TDATA ( rx_payload_s2.tdata ),
    .s_axis_TKEEP ( rx_payload_s2.tkeep ),
    .s_axis_TLAST ( rx_payload_s2.tlast ),
    .s_axis_TSTRB (0),
    .s_meta_TVALID (rx_hdr_s2.valid),
    .s_meta_TREADY (rx_hdr_s2.ready),
    .s_meta_TDATA (rx_hdr_s2.data),
    .m_axis_TREADY ( rx_msg_strm_s0.tready ),
    .m_axis_TVALID ( rx_msg_strm_s0.tvalid ),
    .m_axis_TDATA ( rx_msg_strm_s0.tdata ),
    .m_axis_TKEEP ( rx_msg_strm_s0.tkeep ),
    .m_axis_TLAST ( rx_msg_strm_s0.tlast )
);

axis_reg_array #(.N_STAGES(2)) inst_rx_msg_strm_array (.aclk(aclk), .aresetn(aresetn), .s_axis(rx_msg_strm_s0), .m_axis(rx_msg_strm_s1));

bft_meta_gen_ip rx_net_meta_gen_inst (
    .s_axis_TREADY ( rx_msg_strm_s1.tready ),
    .s_axis_TVALID ( rx_msg_strm_s1.tvalid ),
    .s_axis_TDATA ( rx_msg_strm_s1.tdata ),
    .s_axis_TKEEP ( rx_msg_strm_s1.tkeep ),
    .s_axis_TLAST ( rx_msg_strm_s1.tlast ),
    .s_axis_TSTRB (0),
    .m_meta_TVALID (hostTxMeta.valid),
    .m_meta_TREADY (hostTxMeta.ready),
    .m_meta_TDATA (hostTxMeta.data),
    .m_axis_TREADY ( hostTxData.tready ),
    .m_axis_TVALID ( hostTxData.tvalid ),
    .m_axis_TDATA ( hostTxData.tdata ),
    .m_axis_TKEEP ( hostTxData.tkeep ),
    .m_axis_TLAST ( hostTxData.tlast ),
    .ap_clk(aclk),
    .ap_rst_n(aresetn)
);


axis_meta_register_slice_width_512 bft_tx_stat_slice_width_512(
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready (  ),
    .s_axis_tvalid ( 1'b1 ),
    .s_axis_tdata ( bft_tx_stat_s0 ),
    .m_axis_tready ( 1'b1 ),
    .m_axis_tvalid (  ),
    .m_axis_tdata ( bft_tx_stat_s1 )
);

axis_meta_register_slice_width_512 bft_rx_stat_slice_width_512(
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready (  ),
    .s_axis_tvalid ( 1'b1 ),
    .s_axis_tdata ( bft_rx_stat_s0 ),
    .m_axis_tready ( 1'b1 ),
    .m_axis_tvalid (  ),
    .m_axis_tdata ( bft_rx_stat_s1 )
);


// create pulse when ap_start transitions to 1
logic ap_start_r = 1'b0;

always @(posedge aclk) begin
  begin
    ap_start_r <= ap_start;
  end
end

assign ap_start_pulse = ap_start & ~ap_start_r;

/*
 * Statistics
 */

logic running;

// set ap_done 
always @( posedge aclk ) begin 
	if (~aresetn) begin
		ap_done <= '0;
		running <= 1'b0;
        execution_cycles <= '0;
	end
	else begin
		if (ap_start_pulse) begin
			ap_done <= 1'b0;
			running <= 1'b1;
            execution_cycles <= '0;
		end
		else if (running) begin
            execution_cycles <= execution_cycles + 1'b1;

            if ((exp_tx_net_pkt != 0) & (exp_tx_net_pkt == tx_net_pkt) ) begin
                ap_done <= 1'b1;
			    running <= 1'b0;
            end

            if ((exp_rx_net_pkt != 0) & (exp_rx_net_pkt == rx_net_pkt) ) begin
                ap_done <= 1'b1;
			    running <= 1'b0;
            end
		end
	end
end

always @(posedge aclk) begin
    if (~aresetn) begin
        rx_net_pkt <= '0;
        tx_net_pkt <= '0;
    end
    else begin
        if (ap_start_pulse) begin
            rx_net_pkt <= '0;
            tx_net_pkt <= '0;
        end

        if (netTxData.tvalid & netTxData.tready & netTxData.tlast) begin
            tx_net_pkt <= tx_net_pkt + 1'b1;
        end

        if (netRxData.tvalid & netRxData.tready & netRxData.tlast) begin
            rx_net_pkt <= rx_net_pkt + 1'b1;
        end

    end
end

endmodule