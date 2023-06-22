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
`default_nettype none

import lynxTypes::*;

module rx_engine
(
    input wire                  rx_data_in_tvalid,
    input wire                  rx_data_in_tlast,
    output wire                 rx_data_in_tready,
    input wire [511:0]          rx_data_in_tdata,
    input wire [63:0]           rx_data_in_tkeep,

    input wire                  rx_meta_in_tvalid,
    output wire                 rx_meta_in_tready,
    input wire [63:0]           rx_meta_in_tdata,

    output wire                 rx_data_out_tvalid,
    output wire                 rx_data_out_tlast,
    input wire                  rx_data_out_tready,
    output wire [511:0]         rx_data_out_tdata,
    output wire [63:0]          rx_data_out_tkeep,

    output wire                 rx_meta_out_tvalid,
    input wire                  rx_meta_out_tready,
    output wire [63:0]          rx_meta_out_tdata,

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

// very small meta fifo
axis_meta_fifo_width_64_depth_16 meta_in_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( rx_meta_in_tready ),
    .m_axis_tready ( m_axis_meta_in_fifo_tready ),
    .s_axis_tvalid ( rx_meta_in_tvalid ),
    .s_axis_tdata ( rx_meta_in_tdata ),
    .m_axis_tvalid ( m_axis_meta_in_fifo_tvalid ),
    .m_axis_tdata ( m_axis_meta_in_fifo_tdata )
);

// 8KB fifo to buffer input
axis_data_fifo_width_512_depth_128 rx_data_in_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( rx_data_in_tready ),
    .m_axis_tready ( m_axis_data_in_fifo_tready ),
    .s_axis_tvalid ( rx_data_in_tvalid ),
    .s_axis_tdata ( rx_data_in_tdata ),
    .s_axis_tkeep ( rx_data_in_tkeep ),
    .s_axis_tlast ( rx_data_in_tlast ),
    .m_axis_tvalid ( m_axis_data_in_fifo_tvalid ),
    .m_axis_tdata ( m_axis_data_in_fifo_tdata ),
    .m_axis_tkeep ( m_axis_data_in_fifo_tkeep ),
    .m_axis_tlast ( m_axis_data_in_fifo_tlast )
);

assign rx_meta_out_tvalid = m_axis_meta_in_fifo_tvalid;
assign rx_meta_out_tdata = m_axis_meta_in_fifo_tdata;
assign m_axis_meta_in_fifo_tready = rx_meta_out_tready;

assign rx_data_out_tvalid = m_axis_data_in_fifo_tvalid;
assign rx_data_out_tlast = m_axis_data_in_fifo_tlast;
assign rx_data_out_tdata = m_axis_data_in_fifo_tdata;
assign rx_data_out_tkeep = m_axis_data_in_fifo_tkeep;
assign m_axis_data_in_fifo_tready = rx_data_out_tready;



endmodule
`default_nettype wire