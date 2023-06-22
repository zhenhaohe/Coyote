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

module sha256_module_secworks #( 
  parameter integer  DEBUG = 0
)
(
    
    input wire                  sha256_in_tvalid,
    input wire                  sha256_in_tlast,
    output wire                 sha256_in_tready,
    input wire [511:0]          sha256_in_tdata,
    input wire [63:0]           sha256_in_tkeep,

    output wire                 sha256_out_tvalid,
    input wire                  sha256_out_tready,
    output wire [255:0]         sha256_out_tdata,
    
    // Clock and reset
    input  wire                 aclk,
    input  wire[0:0]            aresetn

);

wire                    sha256_in_reg_tvalid;
wire                    sha256_in_reg_tlast;
wire                    sha256_in_reg_tready;
wire [511:0]            sha256_in_reg_tdata;
wire [63:0]             sha256_in_reg_tkeep;

wire                    sha256_out_reg_tvalid;
wire                    sha256_out_reg_tlast;
wire                    sha256_out_reg_tready;
wire [255:0]            sha256_out_reg_tdata;
wire [31:0]             sha256_out_reg_tkeep;

axis_register_slice_width_512 reg_slice_512 (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tkeep ( sha256_in_tkeep ),
    .s_axis_tlast ( sha256_in_tlast ),
    .s_axis_tready ( sha256_in_tready ),
    .s_axis_tvalid ( sha256_in_tvalid ),
    .s_axis_tdata ( sha256_in_tdata ),
    .m_axis_tkeep ( sha256_in_reg_tkeep ),
    .m_axis_tlast ( sha256_in_reg_tlast ),
    .m_axis_tready ( sha256_in_reg_tready ),
    .m_axis_tvalid ( sha256_in_reg_tvalid ),
    .m_axis_tdata ( sha256_in_reg_tdata )
);

// hold the block_lock during the processing of one block (512 bits)
// from receiving of the input to sending out the output of hash
logic [511:0] s_tdata_i;
logic s_tlast_i;
logic s_tvalid_i;
logic s_tready_o;
logic [255:0] digest_o;
logic digest_valid_o;

logic block_lock;
logic is_last_block;

always_ff @( posedge aclk) begin 
    if (~aresetn) begin
        block_lock <= 1'b0;
        is_last_block <= 1'b0;
    end
    else begin
        if (digest_valid_o & sha256_out_reg_tready & block_lock) begin
            block_lock <= 1'b0;
            is_last_block <= 1'b0;
        end
        else if (s_tvalid_i & s_tready_o) begin
            block_lock <= 1'b1;
            if (s_tlast_i) begin
                is_last_block <= 1'b1;
            end
        end
    end
end



// valid low when output ready is low or during the block lock
assign s_tvalid_i = sha256_in_reg_tvalid & sha256_out_reg_tready & ~block_lock; 
assign s_tdata_i = sha256_in_reg_tdata;
assign s_tlast_i = sha256_in_reg_tlast;
assign sha256_in_reg_tready = s_tready_o & sha256_out_reg_tready & ~block_lock;

sha256_stream sha256_secworks
(   
    .clk(aclk),
    .rst(~aresetn),
    .mode(1),
    .s_tdata_i(s_tdata_i),
    .s_tlast_i(s_tlast_i),
    .s_tvalid_i(s_tvalid_i),
    .s_tready_o(s_tready_o),
    .digest_o(digest_o),
    .digest_valid_o(digest_valid_o)
);

// only assign valid signal when it is last block
assign sha256_out_reg_tvalid = digest_valid_o & is_last_block;
assign sha256_out_reg_tdata = digest_o;

axis_meta_register_slice_width_256 reg_slice_256 (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( sha256_out_reg_tready ),
    .s_axis_tvalid ( sha256_out_reg_tvalid ),
    .s_axis_tdata ( sha256_out_reg_tdata ),
    .m_axis_tready ( sha256_out_tready ),
    .m_axis_tvalid ( sha256_out_tvalid ),
    .m_axis_tdata ( sha256_out_tdata )
);

if (DEBUG) begin
    ila_sha_module_secworks ila_sha_module_secworks
    (
        .clk(aclk), // input wire clk
        .probe0(sha256_in_reg_tready), //1
        .probe1(sha256_in_reg_tvalid), //1
        .probe2(sha256_in_reg_tlast), //1
        .probe3(block_lock), //1
        .probe4(is_last_block), //1
        .probe5(s_tlast_i), //1
        .probe6(s_tvalid_i), //1
        .probe7(s_tready_o),
        .probe8(digest_valid_o),
        .probe9(sha256_out_reg_tvalid),
        .probe10(sha256_out_reg_tready),
        .probe11(s_tdata_i), // 512
        .probe12(digest_o) //256
    );
end


endmodule
`default_nettype wire