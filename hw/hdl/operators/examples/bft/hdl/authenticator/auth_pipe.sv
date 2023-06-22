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


module auth_pipe
#( 
    parameter integer PIPE_INDEX = 0,
    parameter integer OPERATION = 0, //--[0-cbc encryption, 1-cbc decryption, 2-gmac]
    parameter integer VERIFICATION = 0
)
(
    
    input wire                 auth_in_tvalid,
    input wire                 auth_in_tlast,
    output wire                auth_in_tready,
    input wire [511:0]         auth_in_tdata,
    input wire [63:0]          auth_in_tkeep,
    input wire [0:0]           auth_in_tuser,             

    output wire                auth_out_tvalid,
    output wire                auth_out_tlast,
    input wire                 auth_out_tready,
    output wire [511:0]        auth_out_tdata,
    output wire [63:0]         auth_out_tkeep,

    // Clock and reset
    input  wire                 aclk,
    input  wire[0:0]            aresetn

);

logic                   auth_in_reg_tvalid;
logic                   auth_in_reg_tlast;
logic                   auth_in_reg_tready;
logic [511:0]           auth_in_reg_tdata;
logic [63:0]            auth_in_reg_tkeep;
logic [0:0]             auth_in_reg_tuser;   

axis_register_slice_width_512_tuser reg_slice_512_tuser (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tkeep ( auth_in_tkeep ),
    .s_axis_tlast ( auth_in_tlast ),
    .s_axis_tready ( auth_in_tready ),
    .s_axis_tvalid ( auth_in_tvalid ),
    .s_axis_tdata ( auth_in_tdata ),
    .s_axis_tuser ( auth_in_tuser ),
    .m_axis_tkeep ( auth_in_reg_tkeep ),
    .m_axis_tlast ( auth_in_reg_tlast ),
    .m_axis_tready ( auth_in_reg_tready ),
    .m_axis_tvalid ( auth_in_reg_tvalid ),
    .m_axis_tdata ( auth_in_reg_tdata ),
    .m_axis_tuser ( auth_in_reg_tuser )
);

// Use the tuser side channel to distinguish whether input is key init stream or auth message stream
// tusr - 0: auth message stream - 1: auth key init stream
localparam integer NUM_SWITCH_M_AXI = 2;
localparam integer NUM_SWITCH_M_AXI_BITS = $clog2(NUM_SWITCH_M_AXI);

logic [NUM_SWITCH_M_AXI-1:0] m_axis_input_switch_tvalid;
logic [NUM_SWITCH_M_AXI-1:0] m_axis_input_switch_tready;
logic [NUM_SWITCH_M_AXI-1:0] m_axis_input_switch_tlast;
logic [NUM_SWITCH_M_AXI*512-1:0] m_axis_input_switch_tdata;
logic [NUM_SWITCH_M_AXI*64-1:0] m_axis_input_switch_tkeep;
logic [NUM_SWITCH_M_AXI*NUM_SWITCH_M_AXI_BITS-1:0] m_axis_input_switch_tdest;

axis_switch_width_512_1_to_2 axis_switch_width_512_1_to_2_inst (
	.aclk ( aclk ),
	.aresetn ( aresetn ),
	.s_axis_tready ( auth_in_reg_tready ),
	.m_axis_tready ( m_axis_input_switch_tready ),
	.s_axis_tvalid ( auth_in_reg_tvalid ),
	.s_axis_tdata ( auth_in_reg_tdata ),
	.s_axis_tkeep ( auth_in_reg_tkeep ),
	.s_axis_tlast ( auth_in_reg_tlast ),
	.s_axis_tdest ( auth_in_reg_tuser ), // use tusr as the dest signal for the axi switch
	.m_axis_tvalid ( m_axis_input_switch_tvalid ),
	.m_axis_tdata ( m_axis_input_switch_tdata ),
	.m_axis_tkeep ( m_axis_input_switch_tkeep ),
	.m_axis_tlast ( m_axis_input_switch_tlast ),
	.m_axis_tdest ( m_axis_input_switch_tdest ),
	.s_decode_err ( )
);

// auth message stream pipeline
// tusr - 0: auth message stream
// the first word of the message is header, containing index&len information: | Payload | Header(64B) |
// the index&len information are queued in very small fifos
// the message payload is converted from 512 bits to 128 bits block for auth module
logic                   m_axis_msg_input_fifo_tvalid;
logic                   m_axis_msg_input_fifo_tlast;
logic                   m_axis_msg_input_fifo_tready;
logic [511:0]           m_axis_msg_input_fifo_tdata;
logic [63:0]            m_axis_msg_input_fifo_tkeep;

logic                   s_axis_msg_input_fifo_tvalid;
logic                   s_axis_msg_input_fifo_tlast;
logic                   s_axis_msg_input_fifo_tready;
logic [511:0]           s_axis_msg_input_fifo_tdata;
logic [63:0]            s_axis_msg_input_fifo_tkeep;

logic                   m_axis_msg_header_fifo_tvalid;
logic                   m_axis_msg_header_fifo_tlast;
logic                   m_axis_msg_header_fifo_tready;
logic [511:0]           m_axis_msg_header_fifo_tdata;
logic [63:0]            m_axis_msg_header_fifo_tkeep;

logic                   s_axis_msg_header_fifo_tvalid;
logic                   s_axis_msg_header_fifo_tlast;
logic                   s_axis_msg_header_fifo_tready;
logic [511:0]           s_axis_msg_header_fifo_tdata;
logic [63:0]            s_axis_msg_header_fifo_tkeep;

logic                   s_axis_key_lookup_fifo_tvalid;
logic                   s_axis_key_lookup_fifo_tready;
logic [31:0]            s_axis_key_lookup_fifo_tdata;

logic                   m_axis_key_lookup_fifo_tvalid;
logic                   m_axis_key_lookup_fifo_tready;
logic [31:0]            m_axis_key_lookup_fifo_tdata;

logic                   s_axis_len_fifo_tvalid;
logic                   s_axis_len_fifo_tready;
logic [31:0]            s_axis_len_fifo_tdata;

logic                   m_axis_len_fifo_tvalid;
logic                   m_axis_len_fifo_tready;
logic [31:0]            m_axis_len_fifo_tdata;

logic                   s_axis_payload_512_to_128_converter_tvalid;
logic                   s_axis_payload_512_to_128_converter_tlast;
logic                   s_axis_payload_512_to_128_converter_tready;
logic [511:0]           s_axis_payload_512_to_128_converter_tdata;
logic [63:0]            s_axis_payload_512_to_128_converter_tkeep;

logic                   m_axis_payload_512_to_128_converter_tvalid;
logic                   m_axis_payload_512_to_128_converter_tlast;
logic                   m_axis_payload_512_to_128_converter_tready;
logic [127:0]           m_axis_payload_512_to_128_converter_tdata;
logic [15:0]            m_axis_payload_512_to_128_converter_tkeep;

// flag indicates header
logic isHeader;

assign s_axis_msg_input_fifo_tvalid = m_axis_input_switch_tvalid[0];
assign m_axis_input_switch_tready[0] = s_axis_msg_input_fifo_tready;
assign s_axis_msg_input_fifo_tlast = m_axis_input_switch_tlast[0];
assign s_axis_msg_input_fifo_tdata = m_axis_input_switch_tdata[(0+1)*512-1:0*512];
assign s_axis_msg_input_fifo_tkeep = m_axis_input_switch_tkeep[(0+1)*64-1:0*64];

axis_data_fifo_width_512_depth_64 auth_pipeline_input_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( s_axis_msg_input_fifo_tready ),
    .m_axis_tready ( m_axis_msg_input_fifo_tready ),
    .s_axis_tvalid ( s_axis_msg_input_fifo_tvalid ),
    .s_axis_tdata ( s_axis_msg_input_fifo_tdata ),
    .s_axis_tkeep ( s_axis_msg_input_fifo_tkeep ),
    .s_axis_tlast ( s_axis_msg_input_fifo_tlast ),
    .m_axis_tvalid ( m_axis_msg_input_fifo_tvalid ),
    .m_axis_tdata ( m_axis_msg_input_fifo_tdata ),
    .m_axis_tkeep ( m_axis_msg_input_fifo_tkeep ),
    .m_axis_tlast ( m_axis_msg_input_fifo_tlast )
);

assign m_axis_msg_input_fifo_tready = isHeader? (s_axis_key_lookup_fifo_tready & s_axis_msg_header_fifo_tready & s_axis_len_fifo_tready) : s_axis_payload_512_to_128_converter_tready;

always @(posedge aclk) begin
    if (~aresetn) begin
        isHeader <= 1'b1;
    end
    else begin
        if (isHeader & m_axis_msg_input_fifo_tvalid & m_axis_msg_input_fifo_tready) begin
            isHeader <= 1'b0;
        end
        else if (~isHeader & m_axis_msg_input_fifo_tvalid & m_axis_msg_input_fifo_tready & m_axis_msg_input_fifo_tlast) begin
            isHeader <= 1'b1;
        end
    end
end

// payload forwards to width converter

assign s_axis_payload_512_to_128_converter_tvalid = m_axis_msg_input_fifo_tvalid & (~isHeader);
assign s_axis_payload_512_to_128_converter_tlast = m_axis_msg_input_fifo_tlast;
assign s_axis_payload_512_to_128_converter_tdata = m_axis_msg_input_fifo_tdata;
assign s_axis_payload_512_to_128_converter_tkeep = m_axis_msg_input_fifo_tkeep;

axis_dwidth_converter_512_to_128 dwidth_payload_converter_512_to_128 (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( s_axis_payload_512_to_128_converter_tready ),
    .m_axis_tready ( m_axis_payload_512_to_128_converter_tready ),
    .s_axis_tvalid ( s_axis_payload_512_to_128_converter_tvalid ),
    .s_axis_tdata ( s_axis_payload_512_to_128_converter_tdata ),
    .s_axis_tkeep ( s_axis_payload_512_to_128_converter_tkeep ),
    .s_axis_tlast ( s_axis_payload_512_to_128_converter_tlast ),
    .m_axis_tvalid ( m_axis_payload_512_to_128_converter_tvalid ),
    .m_axis_tdata ( m_axis_payload_512_to_128_converter_tdata ),
    .m_axis_tkeep ( m_axis_payload_512_to_128_converter_tkeep ),
    .m_axis_tlast ( m_axis_payload_512_to_128_converter_tlast )
);

// index extracted and queued in a small fifo
// Assume the header has the following format and generate the meta information
// struct headerType
// {
//     ap_uint<32> cmdID; // specifier of different communication primitive
//     ap_uint<32> cmdLen; // total byte len of compulsory & optional cmd fields
//     ap_uint<32> dst; // either dst rank or communicator ID depends on primitive
//     ap_uint<32> src; // src rank
//     ap_uint<32> tag; // tag, reserved
//     ap_uint<32> dataLen; //total byte len of data to each primitive
// };
// also header is stored in a small fifo

assign s_axis_len_fifo_tvalid = m_axis_msg_input_fifo_tvalid & isHeader & s_axis_key_lookup_fifo_tready & s_axis_msg_header_fifo_tready & s_axis_len_fifo_tready;
assign s_axis_len_fifo_tdata = m_axis_msg_input_fifo_tdata[191:160];

assign s_axis_key_lookup_fifo_tvalid = m_axis_msg_input_fifo_tvalid & isHeader & s_axis_key_lookup_fifo_tready & s_axis_msg_header_fifo_tready & s_axis_len_fifo_tready;
assign s_axis_key_lookup_fifo_tdata = m_axis_msg_input_fifo_tdata[95:64];

assign s_axis_msg_header_fifo_tvalid = m_axis_msg_input_fifo_tvalid & isHeader & s_axis_key_lookup_fifo_tready & s_axis_msg_header_fifo_tready & s_axis_len_fifo_tready;
assign s_axis_msg_header_fifo_tlast = m_axis_msg_input_fifo_tlast;
assign s_axis_msg_header_fifo_tdata = m_axis_msg_input_fifo_tdata;
assign s_axis_msg_header_fifo_tkeep = m_axis_msg_input_fifo_tkeep;

axis_meta_fifo_width_32_depth_16 key_lookup_fifo_inst(
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( s_axis_key_lookup_fifo_tready ),
    .m_axis_tready ( m_axis_key_lookup_fifo_tready ),
    .s_axis_tvalid ( s_axis_key_lookup_fifo_tvalid ),
    .s_axis_tdata ( s_axis_key_lookup_fifo_tdata ),
    .m_axis_tvalid ( m_axis_key_lookup_fifo_tvalid ),
    .m_axis_tdata ( m_axis_key_lookup_fifo_tdata )
);

axis_meta_fifo_width_32_depth_16 len_fifo_inst(
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( s_axis_len_fifo_tready ),
    .m_axis_tready ( m_axis_len_fifo_tready ),
    .s_axis_tvalid ( s_axis_len_fifo_tvalid ),
    .s_axis_tdata ( s_axis_len_fifo_tdata ),
    .m_axis_tvalid ( m_axis_len_fifo_tvalid ),
    .m_axis_tdata ( m_axis_len_fifo_tdata )
);

axis_data_fifo_width_512_depth_16 auth_pipeline_header_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( s_axis_msg_header_fifo_tready ),
    .m_axis_tready ( m_axis_msg_header_fifo_tready ),
    .s_axis_tvalid ( s_axis_msg_header_fifo_tvalid ),
    .s_axis_tdata ( s_axis_msg_header_fifo_tdata ),
    .s_axis_tkeep ( s_axis_msg_header_fifo_tkeep ),
    .s_axis_tlast ( s_axis_msg_header_fifo_tlast ),
    .m_axis_tvalid ( m_axis_msg_header_fifo_tvalid ),
    .m_axis_tdata ( m_axis_msg_header_fifo_tdata ),
    .m_axis_tkeep ( m_axis_msg_header_fifo_tkeep ),
    .m_axis_tlast ( m_axis_msg_header_fifo_tlast )
);

logic                   s_axis_auth_module_tvalid;
logic                   s_axis_auth_module_tlast;
logic                   s_axis_auth_module_tready;
logic [127:0]           s_axis_auth_module_tdata;
logic [15:0]            s_axis_auth_module_tkeep;

logic                   m_axis_auth_module_tvalid;
logic                   m_axis_auth_module_tlast;
logic                   m_axis_auth_module_tready;
logic [127:0]           m_axis_auth_module_tdata;
logic [15:0]            m_axis_auth_module_tkeep;

logic key_in_tvalid;
logic key_in_tready;
logic [2048-1:0] key_in_tdata;

logic key_in_tvalid_reg;
logic key_in_tready_reg;
logic [2048-1:0] key_in_tdata_reg;

logic auth_out_fifo_prog_full;

axis_data_fifo_width_128_depth_64 auth_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( m_axis_payload_512_to_128_converter_tready ),
    .m_axis_tready ( s_axis_auth_module_tready & (!auth_out_fifo_prog_full)),
    .s_axis_tvalid ( m_axis_payload_512_to_128_converter_tvalid ),
    .s_axis_tdata ( m_axis_payload_512_to_128_converter_tdata ),
    .s_axis_tkeep ( m_axis_payload_512_to_128_converter_tkeep ),
    .s_axis_tlast ( m_axis_payload_512_to_128_converter_tlast ),
    .m_axis_tvalid ( s_axis_auth_module_tvalid ),
    .m_axis_tdata ( s_axis_auth_module_tdata ),
    .m_axis_tkeep ( s_axis_auth_module_tkeep ),
    .m_axis_tlast ( s_axis_auth_module_tlast )
);

if (OPERATION == 0) begin
    auth_encrypt_module #( 
    .PIPE_INDEX(PIPE_INDEX),
    .OPERATION(OPERATION),
    .VERIFICATION(VERIFICATION)
    )auth_encrypt_module (
        .aclk ( aclk ),
        .aresetn ( aresetn ),
        .s_axis_tready ( s_axis_auth_module_tready ),
        .m_axis_tready ( m_axis_auth_module_tready ),
        .s_axis_tvalid ( s_axis_auth_module_tvalid & (!auth_out_fifo_prog_full) ),
        .s_axis_tdata ( s_axis_auth_module_tdata ),
        .s_axis_tkeep ( s_axis_auth_module_tkeep ),
        .s_axis_tlast ( s_axis_auth_module_tlast ),
        .m_axis_tvalid ( m_axis_auth_module_tvalid ),
        .m_axis_tdata ( m_axis_auth_module_tdata ),
        .m_axis_tkeep ( m_axis_auth_module_tkeep ),
        .m_axis_tlast ( m_axis_auth_module_tlast ),
        .key_in_data(key_in_tdata_reg),
        .key_in_ready(key_in_tready_reg),
        .key_in_valid(key_in_tvalid_reg)
    );

    assign m_axis_len_fifo_tready = 1'b1;
end
else if (OPERATION == 1) begin
    auth_decrypt_module #( 
    .PIPE_INDEX(PIPE_INDEX),
    .OPERATION(OPERATION),
    .VERIFICATION(VERIFICATION)
    )auth_decrypt_module (
        .aclk ( aclk ),
        .aresetn ( aresetn ),
        .s_axis_tready ( s_axis_auth_module_tready ),
        .m_axis_tready ( m_axis_auth_module_tready ),
        .s_axis_tvalid ( s_axis_auth_module_tvalid & (!auth_out_fifo_prog_full) ),
        .s_axis_tdata ( s_axis_auth_module_tdata ),
        .s_axis_tkeep ( s_axis_auth_module_tkeep ),
        .s_axis_tlast ( s_axis_auth_module_tlast ),
        .m_axis_tvalid ( m_axis_auth_module_tvalid ),
        .m_axis_tdata ( m_axis_auth_module_tdata ),
        .m_axis_tkeep ( m_axis_auth_module_tkeep ),
        .m_axis_tlast ( m_axis_auth_module_tlast ),
        .key_in_data(key_in_tdata_reg),
        .key_in_ready(key_in_tready_reg),
        .key_in_valid(key_in_tvalid_reg)
    );

    assign m_axis_len_fifo_tready = 1'b1;
end
else if (OPERATION == 2) begin
    auth_gmac_module #( 
    .PIPE_INDEX(PIPE_INDEX),
    .OPERATION(OPERATION),
    .VERIFICATION(VERIFICATION)
    )auth_gmac_module (
        .aclk ( aclk ),
        .aresetn ( aresetn ),
        .s_axis_tready ( s_axis_auth_module_tready ),
        .m_axis_tready ( m_axis_auth_module_tready ),
        .s_axis_tvalid ( s_axis_auth_module_tvalid & (!auth_out_fifo_prog_full) ),
        .s_axis_tdata ( s_axis_auth_module_tdata ),
        .s_axis_tkeep ( s_axis_auth_module_tkeep ),
        .s_axis_tlast ( s_axis_auth_module_tlast ),
        .m_axis_tvalid ( m_axis_auth_module_tvalid ),
        .m_axis_tdata ( m_axis_auth_module_tdata ),
        .m_axis_tkeep ( m_axis_auth_module_tkeep ),
        .m_axis_tlast ( m_axis_auth_module_tlast ),
        .key_in_data(key_in_tdata_reg),
        .key_in_ready(key_in_tready_reg),
        .key_in_valid(key_in_tvalid_reg),
        .s_axis_meta_tdata(m_axis_len_fifo_tdata),
        .s_axis_meta_tvalid(m_axis_len_fifo_tvalid),
        .s_axis_meta_tready(m_axis_len_fifo_tready)
    );
end

logic                   s_axis_128_to_512_converter_tvalid;
logic                   s_axis_128_to_512_converter_tlast;
logic                   s_axis_128_to_512_converter_tready;
logic [127:0]           s_axis_128_to_512_converter_tdata;
logic [15:0]            s_axis_128_to_512_converter_tkeep;

axis_data_fifo_width_128_depth_64_prog_full auth_out_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( m_axis_auth_module_tready ),
    .m_axis_tready ( s_axis_128_to_512_converter_tready ),
    .s_axis_tvalid ( m_axis_auth_module_tvalid ),
    .s_axis_tdata ( m_axis_auth_module_tdata ),
    .s_axis_tkeep ( m_axis_auth_module_tkeep ),
    .s_axis_tlast ( m_axis_auth_module_tlast ),
    .m_axis_tvalid ( s_axis_128_to_512_converter_tvalid ),
    .m_axis_tdata ( s_axis_128_to_512_converter_tdata ),
    .m_axis_tkeep ( s_axis_128_to_512_converter_tkeep ),
    .m_axis_tlast ( s_axis_128_to_512_converter_tlast ),
    .prog_full(auth_out_fifo_prog_full)
);



logic                   m_axis_128_to_512_converter_tvalid;
logic                   m_axis_128_to_512_converter_tlast;
logic                   m_axis_128_to_512_converter_tready;
logic [511:0]           m_axis_128_to_512_converter_tdata;
logic [63:0]            m_axis_128_to_512_converter_tkeep;

axis_dwidth_converter_128_to_512 dwidth_converter_128_to_512 (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( s_axis_128_to_512_converter_tready ),
    .m_axis_tready ( m_axis_128_to_512_converter_tready ),
    .s_axis_tvalid ( s_axis_128_to_512_converter_tvalid ),
    .s_axis_tdata ( s_axis_128_to_512_converter_tdata ),
    .s_axis_tkeep ( s_axis_128_to_512_converter_tkeep ),
    .s_axis_tlast ( s_axis_128_to_512_converter_tlast ),
    .m_axis_tvalid ( m_axis_128_to_512_converter_tvalid ),
    .m_axis_tdata ( m_axis_128_to_512_converter_tdata ),
    .m_axis_tkeep ( m_axis_128_to_512_converter_tkeep ),
    .m_axis_tlast ( m_axis_128_to_512_converter_tlast )
);

logic                   m_axis_merger_tvalid;
logic                   m_axis_merger_tlast;
logic                   m_axis_merger_tready;
logic [511:0]           m_axis_merger_tdata;
logic [63:0]            m_axis_merger_tkeep;

auth_header_payload_merger_ip auth_header_payload_merger_inst(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .header_strm_in_TDATA(m_axis_msg_header_fifo_tdata),
    .header_strm_in_TVALID(m_axis_msg_header_fifo_tvalid),
    .header_strm_in_TREADY(m_axis_msg_header_fifo_tready),
    .header_strm_in_TKEEP(m_axis_msg_header_fifo_tkeep),
    .header_strm_in_TSTRB(0),
    .header_strm_in_TLAST(m_axis_msg_header_fifo_tlast),
    .payload_strm_in_TDATA(m_axis_128_to_512_converter_tdata),
    .payload_strm_in_TVALID(m_axis_128_to_512_converter_tvalid),
    .payload_strm_in_TREADY(m_axis_128_to_512_converter_tready),
    .payload_strm_in_TKEEP(m_axis_128_to_512_converter_tkeep),
    .payload_strm_in_TSTRB(0),
    .payload_strm_in_TLAST(m_axis_128_to_512_converter_tlast),
    .merge_strm_out_TDATA(m_axis_merger_tdata),
    .merge_strm_out_TVALID(m_axis_merger_tvalid),
    .merge_strm_out_TREADY(m_axis_merger_tready),
    .merge_strm_out_TKEEP(m_axis_merger_tkeep),
    .merge_strm_out_TSTRB(),
    .merge_strm_out_TLAST(m_axis_merger_tlast)
);

logic                   auth_out_reg_tvalid;
logic                   auth_out_reg_tlast;
logic                   auth_out_reg_tready;
logic [511:0]           auth_out_reg_tdata;
logic [63:0]            auth_out_reg_tkeep;

axis_packet_fifo_width_512_depth_64 auth_pipeline_output_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( m_axis_merger_tready ),
    .m_axis_tready ( auth_out_reg_tready ),
    .s_axis_tvalid ( m_axis_merger_tvalid ),
    .s_axis_tdata ( m_axis_merger_tdata ),
    .s_axis_tkeep ( m_axis_merger_tkeep ),
    .s_axis_tlast ( m_axis_merger_tlast ),
    .m_axis_tvalid ( auth_out_reg_tvalid ),
    .m_axis_tdata ( auth_out_reg_tdata ),
    .m_axis_tkeep ( auth_out_reg_tkeep ),
    .m_axis_tlast ( auth_out_reg_tlast )
);

axis_register_slice_width_512 reg_slice_512 (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tkeep ( auth_out_reg_tkeep ),
    .s_axis_tlast ( auth_out_reg_tlast ),
    .s_axis_tready ( auth_out_reg_tready ),
    .s_axis_tvalid ( auth_out_reg_tvalid ),
    .s_axis_tdata ( auth_out_reg_tdata ),
    .m_axis_tkeep ( auth_out_tkeep ),
    .m_axis_tlast ( auth_out_tlast ),
    .m_axis_tready ( auth_out_tready ),
    .m_axis_tvalid ( auth_out_tvalid ),
    .m_axis_tdata ( auth_out_tdata )
);


// auth key init stream pipeline
// tusr - 0: auth message stream - 1: auth key init stream
// For auth cbc, key width set to 2048 bits
// convert the 512 bit data to 2048 bit key and send to key module

logic s_axis_key_handler_fifo_tvalid;
logic s_axis_key_handler_fifo_tready;
logic s_axis_key_handler_fifo_tlast;
logic [512-1:0] s_axis_key_handler_fifo_tdata;
logic [64-1:0] s_axis_key_handler_fifo_tkeep;

logic m_axis_key_handler_fifo_tvalid;
logic m_axis_key_handler_fifo_tready;
logic m_axis_key_handler_fifo_tlast;
logic [512-1:0] m_axis_key_handler_fifo_tdata;
logic [64-1:0] m_axis_key_handler_fifo_tkeep;

logic init_key_strm_in_tvalid;
logic init_key_strm_in_tready;
logic init_key_strm_in_tlast;
logic [2048-1:0] init_key_strm_in_tdata;
logic [256-1:0] init_key_strm_in_tkeep;

assign s_axis_key_handler_fifo_tvalid = m_axis_input_switch_tvalid[1];
assign m_axis_input_switch_tready[1] = s_axis_key_handler_fifo_tready;
assign s_axis_key_handler_fifo_tlast = m_axis_input_switch_tlast[1];
assign s_axis_key_handler_fifo_tdata = m_axis_input_switch_tdata[(1+1)*512-1:1*512];
assign s_axis_key_handler_fifo_tkeep = m_axis_input_switch_tkeep[(1+1)*64-1:1*64];


axis_data_fifo_width_512_depth_16 auth_key_handler_fifo(
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( s_axis_key_handler_fifo_tready ),
    .m_axis_tready ( m_axis_key_handler_fifo_tready ),
    .s_axis_tvalid ( s_axis_key_handler_fifo_tvalid ),
    .s_axis_tdata ( s_axis_key_handler_fifo_tdata ),
    .s_axis_tkeep ( s_axis_key_handler_fifo_tkeep ),
    .s_axis_tlast ( s_axis_key_handler_fifo_tlast ),
    .m_axis_tvalid ( m_axis_key_handler_fifo_tvalid ),
    .m_axis_tdata ( m_axis_key_handler_fifo_tdata ),
    .m_axis_tkeep ( m_axis_key_handler_fifo_tkeep ),
    .m_axis_tlast ( m_axis_key_handler_fifo_tlast )
);

axis_dwidth_converter_512_to_2048 axis_dwidth_converter_512_to_2048_inst(
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( m_axis_key_handler_fifo_tready ),
    .m_axis_tready ( init_key_strm_in_tready ),
    .s_axis_tvalid ( m_axis_key_handler_fifo_tvalid ),
    .s_axis_tdata ( m_axis_key_handler_fifo_tdata ),
    .s_axis_tkeep ( m_axis_key_handler_fifo_tkeep ),
    .s_axis_tlast ( m_axis_key_handler_fifo_tlast ),
    .m_axis_tvalid ( init_key_strm_in_tvalid ),
    .m_axis_tdata ( init_key_strm_in_tdata ),
    .m_axis_tkeep ( init_key_strm_in_tkeep ),
    .m_axis_tlast ( init_key_strm_in_tlast )
);

auth_key_handler_ip auth_key_handler_inst(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .init_key_strm_in_TDATA(init_key_strm_in_tdata),
    .init_key_strm_in_TVALID(init_key_strm_in_tvalid),
    .init_key_strm_in_TREADY(init_key_strm_in_tready),
    .init_key_strm_in_TKEEP(init_key_strm_in_tkeep),
    .init_key_strm_in_TSTRB(0),
    .init_key_strm_in_TLAST(init_key_strm_in_tlast),
    .key_resp_out_V_V_TDATA(key_in_tdata),
    .key_resp_out_V_V_TVALID(key_in_tvalid),
    .key_resp_out_V_V_TREADY(key_in_tready),
    .key_lookup_in_V_V_TDATA(m_axis_key_lookup_fifo_tdata),
    .key_lookup_in_V_V_TVALID(m_axis_key_lookup_fifo_tvalid),
    .key_lookup_in_V_V_TREADY(m_axis_key_lookup_fifo_tready)
);

axis_meta_register_slice_width_2048 axis_meta_register_slice_key
(
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( key_in_tready ),
    .m_axis_tready ( key_in_tready_reg ),
    .s_axis_tvalid ( key_in_tvalid ),
    .s_axis_tdata ( key_in_tdata ),
    .m_axis_tvalid ( key_in_tvalid_reg ),
    .m_axis_tdata ( key_in_tdata_reg )
);
localparam integer DEBUG = (PIPE_INDEX == 0) & (VERIFICATION == 1);

if (DEBUG) begin
    ila_auth_pipe ila_auth_pipe
    (
        .clk(aclk), // input wire clk
        // msg input
        .probe0(m_axis_msg_input_fifo_tvalid),  //1
        .probe1(m_axis_msg_input_fifo_tready), //1
        .probe2(m_axis_msg_input_fifo_tlast), //1
        .probe3(auth_out_fifo_prog_full), // 1
        // payload input 
        .probe4(s_axis_auth_module_tvalid), //1
        .probe5(s_axis_auth_module_tready), //1
        .probe6(s_axis_auth_module_tlast), //1
        .probe7(s_axis_auth_module_tdata), // 128
        // header meta
        .probe8(m_axis_key_lookup_fifo_tvalid), // 1
        .probe9(m_axis_key_lookup_fifo_tready), //1
        .probe10(m_axis_key_lookup_fifo_tdata), // 32
        // init key
        .probe11(m_axis_key_handler_fifo_tvalid), //1
        .probe12(m_axis_key_handler_fifo_tready), //1
        .probe13(m_axis_key_handler_fifo_tdata), //512
        .probe14(m_axis_key_handler_fifo_tlast), //1
        // key resp
        .probe15(key_in_tvalid), //1
        .probe16(key_in_tready), //1
        // auth payload output
        .probe17(m_axis_auth_module_tdata), //128
        .probe18(m_axis_auth_module_tvalid), //1
        .probe19(m_axis_auth_module_tready), //1
        .probe20(m_axis_auth_module_tlast), //1
        // key look
        .probe21(s_axis_key_lookup_fifo_tvalid), //1
        .probe22(s_axis_key_lookup_fifo_tready), //1
        
        .probe23(s_axis_msg_header_fifo_tready), //1
        .probe24(s_axis_msg_header_fifo_tvalid), //1
        
        .probe25(s_axis_payload_512_to_128_converter_tready), //1
        .probe26(s_axis_payload_512_to_128_converter_tvalid) //1
    );
end


endmodule
`default_nettype wire