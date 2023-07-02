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

module tx_engine
(
    input wire                  tx_data_in_tvalid,
    input wire                  tx_data_in_tlast,
    output wire                 tx_data_in_tready,
    input wire [511:0]          tx_data_in_tdata,
    input wire [63:0]           tx_data_in_tkeep,

    input wire                  tx_meta_in_tvalid,
    output wire                 tx_meta_in_tready,
    input wire [63:0]           tx_meta_in_tdata,

    output wire                 tx_data_out_tvalid,
    output wire                 tx_data_out_tlast,
    input wire                  tx_data_out_tready,
    output wire [511:0]         tx_data_out_tdata,
    output wire [63:0]          tx_data_out_tkeep,

    output wire                 tx_meta_out_tvalid,
    input wire                  tx_meta_out_tready,
    output wire [63:0]          tx_meta_out_tdata,

    output wire                 lookup_req_tvalid,
    input wire                  lookup_req_tready,
    output wire [31:0]          lookup_req_tdata,

    input wire                  lookup_resp_tvalid,
    output wire                 lookup_resp_tready,
    input wire [127:0]          lookup_resp_tdata,

    // Clock and reset
    input  wire                 aclk,
    input  wire[0:0]            aresetn

);


logic                 m_axis_meta_in_fifo_tvalid;
logic                 m_axis_meta_in_fifo_tready;
logic [63:0]          m_axis_meta_in_fifo_tdata;

logic                   m_axis_data_in_fifo_tvalid;
logic                   m_axis_data_in_fifo_tlast;
logic                   m_axis_data_in_fifo_tready;
logic [511:0]           m_axis_data_in_fifo_tdata;
logic [63:0]            m_axis_data_in_fifo_tkeep;

logic                 s_axis_meta_out_fifo_tvalid;
logic                 s_axis_meta_out_fifo_tready;
logic [63:0]          s_axis_meta_out_fifo_tdata;

logic                   s_axis_data_out_fifo_tvalid;
logic                   s_axis_data_out_fifo_tlast;
logic                   s_axis_data_out_fifo_tready;
logic [511:0]           s_axis_data_out_fifo_tdata;
logic [63:0]            s_axis_data_out_fifo_tkeep;

logic                 s_axis_req_fifo_tvalid;
logic                 s_axis_req_fifo_tready;
logic [31:0]          s_axis_req_fifo_tdata;

logic                   m_axis_resp_fifo_tvalid;
logic                   m_axis_resp_fifo_tready;
logic [127:0]           m_axis_resp_fifo_tdata;

// very small meta fifo
axis_meta_fifo_width_64_depth_16 meta_in_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( tx_meta_in_tready ),
    .m_axis_tready ( m_axis_meta_in_fifo_tready ),
    .s_axis_tvalid ( tx_meta_in_tvalid ),
    .s_axis_tdata ( tx_meta_in_tdata ),
    .m_axis_tvalid ( m_axis_meta_in_fifo_tvalid ),
    .m_axis_tdata ( m_axis_meta_in_fifo_tdata )
);

// 8KB fifo to buffer input
axis_data_fifo_width_512_depth_128 tx_data_in_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( tx_data_in_tready ),
    .m_axis_tready ( m_axis_data_in_fifo_tready ),
    .s_axis_tvalid ( tx_data_in_tvalid ),
    .s_axis_tdata ( tx_data_in_tdata ),
    .s_axis_tkeep ( tx_data_in_tkeep ),
    .s_axis_tlast ( tx_data_in_tlast ),
    .m_axis_tvalid ( m_axis_data_in_fifo_tvalid ),
    .m_axis_tdata ( m_axis_data_in_fifo_tdata ),
    .m_axis_tkeep ( m_axis_data_in_fifo_tkeep ),
    .m_axis_tlast ( m_axis_data_in_fifo_tlast )
);

// Issue communication lookup, convert rank to session
// pad the data to be multiple of 64
// the actual data size is within the message header
txEngine_ip txEngine_ip_inst (
    .netTxCmd_in_TDATA(m_axis_meta_in_fifo_tdata),
    .netTxCmd_in_TVALID(m_axis_meta_in_fifo_tvalid),
    .netTxCmd_in_TREADY(m_axis_meta_in_fifo_tready),

    .netTxData_in_TDATA(m_axis_data_in_fifo_tdata),
    .netTxData_in_TKEEP(m_axis_data_in_fifo_tkeep),
    .netTxData_in_TSTRB(0),
    .netTxData_in_TLAST(m_axis_data_in_fifo_tlast),
    .netTxData_in_TVALID(m_axis_data_in_fifo_tvalid),
    .netTxData_in_TREADY(m_axis_data_in_fifo_tready),

    .netTxCmd_out_TDATA(s_axis_meta_out_fifo_tdata),
    .netTxCmd_out_TVALID(s_axis_meta_out_fifo_tvalid),
    .netTxCmd_out_TREADY(s_axis_meta_out_fifo_tready),

    .netTxData_out_TDATA(s_axis_data_out_fifo_tdata),
    .netTxData_out_TKEEP(s_axis_data_out_fifo_tkeep),
    .netTxData_out_TSTRB(),
    .netTxData_out_TLAST(s_axis_data_out_fifo_tlast),
    .netTxData_out_TVALID(s_axis_data_out_fifo_tvalid),
    .netTxData_out_TREADY(s_axis_data_out_fifo_tready),


    .commLookupReq_TDATA(s_axis_req_fifo_tdata),
    .commLookupReq_TVALID(s_axis_req_fifo_tvalid),
    .commLookupReq_TREADY(s_axis_req_fifo_tready),

    .commLookupResp_TDATA(m_axis_resp_fifo_tdata),
    .commLookupResp_TVALID(m_axis_resp_fifo_tvalid),
    .commLookupResp_TREADY(m_axis_resp_fifo_tready),
    
    .ap_clk(aclk),
    .ap_rst_n(aresetn)
);


// very small meta fifo
axis_meta_fifo_width_64_depth_16 meta_out_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( s_axis_meta_out_fifo_tready ),
    .m_axis_tready ( tx_meta_out_tready ),
    .s_axis_tvalid ( s_axis_meta_out_fifo_tvalid ),
    .s_axis_tdata ( s_axis_meta_out_fifo_tdata ),
    .m_axis_tvalid ( tx_meta_out_tvalid ),
    .m_axis_tdata ( tx_meta_out_tdata )
);

// 8KB fifo to buffer output
axis_data_fifo_width_512_depth_128 tx_data_out_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( s_axis_data_out_fifo_tready ),
    .m_axis_tready ( tx_data_out_tready ),
    .s_axis_tvalid ( s_axis_data_out_fifo_tvalid ),
    .s_axis_tdata ( s_axis_data_out_fifo_tdata ),
    .s_axis_tkeep ( s_axis_data_out_fifo_tkeep ),
    .s_axis_tlast ( s_axis_data_out_fifo_tlast ),
    .m_axis_tvalid ( tx_data_out_tvalid ),
    .m_axis_tdata ( tx_data_out_tdata ),
    .m_axis_tkeep ( tx_data_out_tkeep ),
    .m_axis_tlast ( tx_data_out_tlast )
);


// very small req fifo
axis_meta_fifo_width_32_depth_16 req_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( s_axis_req_fifo_tready ),
    .m_axis_tready ( lookup_req_tready ),
    .s_axis_tvalid ( s_axis_req_fifo_tvalid ),
    .s_axis_tdata ( s_axis_req_fifo_tdata ),
    .m_axis_tvalid ( lookup_req_tvalid ),
    .m_axis_tdata ( lookup_req_tdata )
);


// very small resp fifo
axis_meta_fifo_width_128_depth_16 resp_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( lookup_resp_tready ),
    .m_axis_tready ( m_axis_resp_fifo_tready ),
    .s_axis_tvalid ( lookup_resp_tvalid ),
    .s_axis_tdata ( lookup_resp_tdata ),
    .m_axis_tvalid ( m_axis_resp_fifo_tvalid ),
    .m_axis_tdata ( m_axis_resp_fifo_tdata )
);

// ila_ccl_tx_engine ila_ccl_tx_engine
// (
//  .clk(aclk), // input wire clk
//   .probe0(m_axis_meta_in_fifo_tvalid), //1
//   .probe1(m_axis_meta_in_fifo_tready), // 1
//   .probe2(m_axis_data_in_fifo_tready), // 1
//   .probe3(m_axis_data_in_fifo_tvalid), // 1
//   .probe4(m_axis_data_in_fifo_tlast), //1
//   .probe5(s_axis_meta_out_fifo_tvalid), //1
//   .probe6(s_axis_meta_out_fifo_tready), //1
//   .probe7(s_axis_data_out_fifo_tready), //1
//   .probe8(s_axis_data_out_fifo_tvalid),  //1
//   .probe9(s_axis_data_out_fifo_tlast), //1
//   .probe10(s_axis_req_fifo_tvalid), //1
//   .probe11(s_axis_req_fifo_tready), //1
//   .probe12(m_axis_resp_fifo_tvalid), //1
//   .probe13(m_axis_resp_fifo_tready) //1
//  ); 

endmodule
