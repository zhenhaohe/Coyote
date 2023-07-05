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

module ccl_engine
(
    AXI4S.s                     tx_data_in,
    metaIntf.s                  tx_meta_in,

    AXI4S.m                     net_tx_data_out,
    metaIntf.m                  net_tx_meta_out,

    AXI4S.s                     net_rx_data_in,
    metaIntf.s                  net_rx_meta_in,

    AXI4S.m                     rx_data_out,
    metaIntf.m                  rx_meta_out,

    metaIntf.s                  configComm_in,

    // Clock and reset
    input  wire                 aclk,
    input  wire[0:0]            aresetn

);

metaIntf #(.STYPE(32)) lookup_req();
metaIntf #(.STYPE(128)) lookup_resp();
metaIntf #(.STYPE(64)) comm_config();


tx_engine tx_engine
(
    .tx_data_in_tvalid(tx_data_in.tvalid),
    .tx_data_in_tlast(tx_data_in.tlast),
    .tx_data_in_tready(tx_data_in.tready),
    .tx_data_in_tdata(tx_data_in.tdata),
    .tx_data_in_tkeep(tx_data_in.tkeep),

    .tx_meta_in_tvalid(tx_meta_in.valid),
    .tx_meta_in_tready(tx_meta_in.ready),
    .tx_meta_in_tdata(tx_meta_in.data),

    .tx_data_out_tvalid(net_tx_data_out.tvalid),
    .tx_data_out_tlast(net_tx_data_out.tlast),
    .tx_data_out_tready(net_tx_data_out.tready),
    .tx_data_out_tdata(net_tx_data_out.tdata),
    .tx_data_out_tkeep(net_tx_data_out.tkeep),

    .tx_meta_out_tvalid(net_tx_meta_out.valid),
    .tx_meta_out_tready(net_tx_meta_out.ready),
    .tx_meta_out_tdata(net_tx_meta_out.data),

    .lookup_req_tvalid(lookup_req.valid),
    .lookup_req_tready(lookup_req.ready),
    .lookup_req_tdata(lookup_req.data),

    .lookup_resp_tvalid(lookup_resp.valid),
    .lookup_resp_tready(lookup_resp.ready),
    .lookup_resp_tdata(lookup_resp.data),

    // Clock and reset
    .aclk(aclk),
    .aresetn(aresetn)

);

rx_engine rx_engine
(
    .rx_data_in_tvalid(net_rx_data_in.tvalid),
    .rx_data_in_tlast(net_rx_data_in.tlast),
    .rx_data_in_tready(net_rx_data_in.tready),
    .rx_data_in_tdata(net_rx_data_in.tdata),
    .rx_data_in_tkeep(net_rx_data_in.tkeep),

    .rx_meta_in_tvalid(net_rx_meta_in.valid),
    .rx_meta_in_tready(net_rx_meta_in.ready),
    .rx_meta_in_tdata(net_rx_meta_in.data),

    .rx_data_out_tvalid(rx_data_out.tvalid),
    .rx_data_out_tlast(rx_data_out.tlast),
    .rx_data_out_tready(rx_data_out.tready),
    .rx_data_out_tdata(rx_data_out.tdata),
    .rx_data_out_tkeep(rx_data_out.tkeep),

    .rx_meta_out_tvalid(rx_meta_out.valid),
    .rx_meta_out_tready(rx_meta_out.ready),
    .rx_meta_out_tdata(rx_meta_out.data),

    // Clock and reset
    .aclk(aclk),
    .aresetn(aresetn)
);


axis_meta_fifo_width_64_depth_16 config_comm_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( configComm_in.ready ),
    .m_axis_tready ( comm_config.ready ),
    .s_axis_tvalid ( configComm_in.valid ),
    .s_axis_tdata ( configComm_in.data ),
    .m_axis_tvalid ( comm_config.valid ),
    .m_axis_tdata ( comm_config.data )
);

communicator_ip communicator_ip_inst (
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .commConfigCmd_TDATA(comm_config.data),
    .commConfigCmd_TVALID(comm_config.valid),
    .commConfigCmd_TREADY(comm_config.ready),
    .commLookupReq_TDATA(lookup_req.data),
    .commLookupReq_TVALID(lookup_req.valid),
    .commLookupReq_TREADY(lookup_req.ready),
    .commLookupResp_TDATA(lookup_resp.data),
    .commLookupResp_TVALID(lookup_resp.valid),
    .commLookupResp_TREADY(lookup_resp.ready)
);


endmodule
