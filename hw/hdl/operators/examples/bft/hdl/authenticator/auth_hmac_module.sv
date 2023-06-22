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

// Wrapper function of auth hmac
module auth_hmac_module 
#( 
    parameter integer PIPE_INDEX = 0,
    parameter integer OPERATION = 0, //--[0-cbc encryption, 1-cbc decryption, 2-hmac]
    parameter integer VERIFICATION = 0
)
(
    
    input wire                  s_axis_tvalid,
    input wire                  s_axis_tlast,
    output wire                 s_axis_tready,
    input wire [127:0]          s_axis_tdata,
    input wire [15:0]           s_axis_tkeep,

    output wire                 m_axis_tvalid,
    output wire                 m_axis_tlast,
    input wire                  m_axis_tready,
    output wire [127:0]         m_axis_tdata,
    output wire [15:0]          m_axis_tkeep,

    input wire [63:0]           s_axis_meta_tdata,
    input wire                  s_axis_meta_tvalid,
    output wire                 s_axis_meta_tready,

    input wire [2047:0]         key_in_data,
    output wire                 key_in_ready,
    input wire                  key_in_valid,

    // Clock and reset
    input  wire                 aclk,
    input  wire[0:0]            aresetn

);

localparam integer DEBUG = (PIPE_INDEX == 0) & (VERIFICATION == 1);

logic [127:0] s_axis_cipfer_fifo_tdata;
logic s_axis_cipfer_fifo_tready;
logic s_axis_cipfer_fifo_tvalid;

logic [127:0] cipherkeyStrm_V_TDATA;
logic cipherkeyStrm_V_TREADY;
logic cipherkeyStrm_V_TVALID;

logic [127:0] s_axis_iv_fifo_tdata;
logic s_axis_cipfer_iv_tready;
logic s_axis_cipfer_iv_tvalid;

logic [127:0] IVStrm_V_TDATA;
logic IVStrm_V_TREADY;
logic IVStrm_V_TVALID;

assign key_in_ready = s_axis_cipfer_fifo_tready & s_axis_cipfer_iv_tready;
assign s_axis_cipfer_fifo_tvalid = key_in_valid & key_in_ready;
assign s_axis_cipfer_iv_tvalid = key_in_valid & key_in_ready;

assign s_axis_cipfer_fifo_tdata = key_in_data[127:0];
assign s_axis_iv_fifo_tdata = key_in_data[255:128];

axis_meta_fifo_width_128_depth_16 cipher_fifo_inst(
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( s_axis_cipfer_fifo_tready ),
    .m_axis_tready ( cipherkeyStrm_V_TREADY ),
    .s_axis_tvalid ( s_axis_cipfer_fifo_tvalid ),
    .s_axis_tdata ( s_axis_cipfer_fifo_tdata ),
    .m_axis_tvalid ( cipherkeyStrm_V_TVALID ),
    .m_axis_tdata ( cipherkeyStrm_V_TDATA )
);

axis_meta_fifo_width_128_depth_16 IV_fifo_inst(
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( s_axis_cipfer_iv_tready ),
    .m_axis_tready ( IVStrm_V_TREADY ),
    .s_axis_tvalid ( s_axis_cipfer_iv_tvalid ),
    .s_axis_tdata ( s_axis_iv_fifo_tdata ),
    .m_axis_tvalid ( IVStrm_V_TVALID ),
    .m_axis_tdata ( IVStrm_V_TDATA )
);

auth128GmacTop auth128GmacTop(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .dataStrm_V_TDATA(s_axis_tdata),
    .dataStrm_V_TVALID(s_axis_tvalid),
    .dataStrm_V_TREADY(s_axis_tready),
    .lenDataStrm_V_TDATA(s_axis_meta_tdata),
    .lenDataStrm_V_TVALID(s_axis_meta_tvalid),
    .lenDataStrm_V_TREADY(s_axis_meta_tready),
    .cipherkeyStrm_V_TDATA(cipherkeyStrm_V_TDATA),
    .cipherkeyStrm_V_TVALID(cipherkeyStrm_V_TVALID),
    .cipherkeyStrm_V_TREADY(cipherkeyStrm_V_TREADY),
    .IVStrm_V_TDATA(IVStrm_V_TDATA),
    .IVStrm_V_TVALID(IVStrm_V_TVALID),
    .IVStrm_V_TREADY(IVStrm_V_TREADY),
    .tagStrm_V_TDATA(m_axis_tdata),
    .tagStrm_V_TVALID(m_axis_tvalid),
    .tagStrm_V_TREADY(m_axis_tready)
);

assign m_axis_tkeep = '1;
assign m_axis_tlast = 1'b1;

if (DEBUG) begin
   ila_auth_hmac_module ila_auth_hmac_module
   (
       .clk(aclk), // input wire clk
       .probe0(s_axis_tvalid), //1
       .probe1(s_axis_tready), //1
       .probe2(s_axis_meta_tvalid), //1
       .probe3(s_axis_meta_tready), //1
       .probe4(cipherkeyStrm_V_TVALID), //1
       .probe5(cipherkeyStrm_V_TREADY), //1
       .probe6(IVStrm_V_TREADY), //1
       .probe7(IVStrm_V_TVALID), //1
       .probe8(m_axis_tvalid), //1
       .probe9(m_axis_tready), //1
       .probe10(s_axis_meta_tdata), //64
       .probe11(s_axis_tdata), //128
       .probe12(cipherkeyStrm_V_TDATA), //128
       .probe13(IVStrm_V_TDATA), //128
       .probe14(m_axis_tdata) //128
   );
end 

endmodule
`default_nettype wire