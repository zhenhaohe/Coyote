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

`include "axi_macros.svh"
`include "lynx_macros.svh"

import lynxTypes::*;

module sha256_cluster #( 
    parameter integer NUM_ENGINE = 8,
    parameter integer SHA_MODULE_VERSION = 0,
    parameter integer DEBUG = 0
)
(
    
    input wire                  sha256_in_tvalid,
    input wire                  sha256_in_tlast,
    output wire                 sha256_in_tready,
    input wire [511:0]          sha256_in_tdata,
    input wire [63:0]           sha256_in_tkeep,

    output wire                 sha256_out_tvalid,
    output wire                 sha256_out_tlast,
    input wire                  sha256_out_tready,
    output wire [511:0]         sha256_out_tdata,
    output wire [63:0]          sha256_out_tkeep,

    input wire [7:0]            num_engine,

    // Clock and reset
    input  wire                 aclk,
    input  wire[0:0]            aresetn

);

logic                   m_axis_input_fifo_tvalid;
logic                   m_axis_input_fifo_tlast;
logic                   m_axis_input_fifo_tready;
logic [511:0]           m_axis_input_fifo_tdata;
logic [63:0]            m_axis_input_fifo_tkeep;

// 8KB fifo to buffer input
axis_data_fifo_width_512_depth_128 sha256_input_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( sha256_in_tready ),
    .m_axis_tready ( m_axis_input_fifo_tready ),
    .s_axis_tvalid ( sha256_in_tvalid ),
    .s_axis_tdata ( sha256_in_tdata ),
    .s_axis_tkeep ( sha256_in_tkeep ),
    .s_axis_tlast ( sha256_in_tlast ),
    .m_axis_tvalid ( m_axis_input_fifo_tvalid ),
    .m_axis_tdata ( m_axis_input_fifo_tdata ),
    .m_axis_tkeep ( m_axis_input_fifo_tkeep ),
    .m_axis_tlast ( m_axis_input_fifo_tlast )
);

logic                   m_axis_512_to_64_converter_tvalid;
logic                   m_axis_512_to_64_converter_tlast;
logic                   m_axis_512_to_64_converter_tready;
logic [63:0]            m_axis_512_to_64_converter_tdata;
logic [7:0]             m_axis_512_to_64_converter_tkeep;

// convert to 64 bit
axis_dwidth_converter_512_to_64 dwidth_converter_512_to_64 (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( m_axis_input_fifo_tready ),
    .m_axis_tready ( m_axis_512_to_64_converter_tready ),
    .s_axis_tvalid ( m_axis_input_fifo_tvalid ),
    .s_axis_tdata ( m_axis_input_fifo_tdata ),
    .s_axis_tkeep ( m_axis_input_fifo_tkeep ),
    .s_axis_tlast ( m_axis_input_fifo_tlast ),
    .m_axis_tvalid ( m_axis_512_to_64_converter_tvalid ),
    .m_axis_tdata ( m_axis_512_to_64_converter_tdata ),
    .m_axis_tkeep ( m_axis_512_to_64_converter_tkeep ),
    .m_axis_tlast ( m_axis_512_to_64_converter_tlast )
);

// axis switch to multiplex data
localparam integer NUM_ENGINE_BITS = $clog2(NUM_ENGINE);

logic [NUM_ENGINE-1:0] m_axis_input_switch_tvalid;
logic [NUM_ENGINE-1:0] m_axis_input_switch_tready;
logic [NUM_ENGINE-1:0] m_axis_input_switch_tlast;
logic [NUM_ENGINE*64-1:0] m_axis_input_switch_tdata;
logic [NUM_ENGINE*8-1:0] m_axis_input_switch_tkeep;
logic [NUM_ENGINE*NUM_ENGINE_BITS-1:0] m_axis_input_switch_tdest;

logic [NUM_ENGINE_BITS-1:0] s_axis_input_switch_tdest;

logic [7:0]  num_engine_reg;

always_ff @( posedge aclk ) begin 
    if (~aresetn) begin
        s_axis_input_switch_tdest <= '0;
    end
    else begin
        num_engine_reg <= num_engine;

        if (m_axis_512_to_64_converter_tready & m_axis_512_to_64_converter_tvalid & m_axis_512_to_64_converter_tlast) begin
            s_axis_input_switch_tdest <= s_axis_input_switch_tdest + 1;
            if (s_axis_input_switch_tdest == num_engine_reg - 1) begin
                s_axis_input_switch_tdest <= '0;
            end
        end
    end 
end

if (NUM_ENGINE == 1) begin
    assign m_axis_input_switch_tvalid = m_axis_512_to_64_converter_tvalid;
    assign m_axis_input_switch_tdata = m_axis_512_to_64_converter_tdata;
    assign m_axis_input_switch_tkeep = m_axis_512_to_64_converter_tkeep;
    assign m_axis_input_switch_tlast = m_axis_512_to_64_converter_tlast;
    assign m_axis_512_to_64_converter_tready = m_axis_input_switch_tready;
end
else if (NUM_ENGINE == 2) begin
    axis_switch_width_64_1_to_2 axis_switch_width_64_1_to_2 (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( m_axis_512_to_64_converter_tready ),
    .m_axis_tready ( m_axis_input_switch_tready ),
    .s_axis_tvalid ( m_axis_512_to_64_converter_tvalid ),
    .s_axis_tdata ( m_axis_512_to_64_converter_tdata ),
    .s_axis_tkeep ( m_axis_512_to_64_converter_tkeep ),
    .s_axis_tlast ( m_axis_512_to_64_converter_tlast ),
    .s_axis_tdest ( s_axis_input_switch_tdest ),
    .m_axis_tvalid ( m_axis_input_switch_tvalid ),
    .m_axis_tdata ( m_axis_input_switch_tdata ),
    .m_axis_tkeep ( m_axis_input_switch_tkeep ),
    .m_axis_tlast ( m_axis_input_switch_tlast ),
    .m_axis_tdest ( m_axis_input_switch_tdest ),
    .s_decode_err ( )
    );
end
else if (NUM_ENGINE == 4) begin
    axis_switch_width_64_1_to_4 axis_switch_width_64_1_to_4 (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( m_axis_512_to_64_converter_tready ),
    .m_axis_tready ( m_axis_input_switch_tready ),
    .s_axis_tvalid ( m_axis_512_to_64_converter_tvalid ),
    .s_axis_tdata ( m_axis_512_to_64_converter_tdata ),
    .s_axis_tkeep ( m_axis_512_to_64_converter_tkeep ),
    .s_axis_tlast ( m_axis_512_to_64_converter_tlast ),
    .s_axis_tdest ( s_axis_input_switch_tdest ),
    .m_axis_tvalid ( m_axis_input_switch_tvalid ),
    .m_axis_tdata ( m_axis_input_switch_tdata ),
    .m_axis_tkeep ( m_axis_input_switch_tkeep ),
    .m_axis_tlast ( m_axis_input_switch_tlast ),
    .m_axis_tdest ( m_axis_input_switch_tdest ),
    .s_decode_err ( )
    );
end
else if (NUM_ENGINE == 6) begin
    axis_switch_width_64_1_to_6 axis_switch_width_64_1_to_6 (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( m_axis_512_to_64_converter_tready ),
    .m_axis_tready ( m_axis_input_switch_tready ),
    .s_axis_tvalid ( m_axis_512_to_64_converter_tvalid ),
    .s_axis_tdata ( m_axis_512_to_64_converter_tdata ),
    .s_axis_tkeep ( m_axis_512_to_64_converter_tkeep ),
    .s_axis_tlast ( m_axis_512_to_64_converter_tlast ),
    .s_axis_tdest ( s_axis_input_switch_tdest ),
    .m_axis_tvalid ( m_axis_input_switch_tvalid ),
    .m_axis_tdata ( m_axis_input_switch_tdata ),
    .m_axis_tkeep ( m_axis_input_switch_tkeep ),
    .m_axis_tlast ( m_axis_input_switch_tlast ),
    .m_axis_tdest ( m_axis_input_switch_tdest ),
    .s_decode_err ( )
    );
end
else if (NUM_ENGINE == 8) begin
    axis_switch_width_64_1_to_8 axis_switch_width_64_1_to_8 (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( m_axis_512_to_64_converter_tready ),
    .m_axis_tready ( m_axis_input_switch_tready ),
    .s_axis_tvalid ( m_axis_512_to_64_converter_tvalid ),
    .s_axis_tdata ( m_axis_512_to_64_converter_tdata ),
    .s_axis_tkeep ( m_axis_512_to_64_converter_tkeep ),
    .s_axis_tlast ( m_axis_512_to_64_converter_tlast ),
    .s_axis_tdest ( s_axis_input_switch_tdest ),
    .m_axis_tvalid ( m_axis_input_switch_tvalid ),
    .m_axis_tdata ( m_axis_input_switch_tdata ),
    .m_axis_tkeep ( m_axis_input_switch_tkeep ),
    .m_axis_tlast ( m_axis_input_switch_tlast ),
    .m_axis_tdest ( m_axis_input_switch_tdest ),
    .s_decode_err ( )
    );
end

// multiple sha pipelines
// input data path 64 bits
// output data path 64 bits
logic [NUM_ENGINE-1:0] m_axis_pipeline_tvalid;
logic [NUM_ENGINE-1:0] m_axis_pipeline_tready;
logic [NUM_ENGINE-1:0] m_axis_pipeline_tlast;
logic [NUM_ENGINE*64-1:0] m_axis_pipeline_tdata;
logic [NUM_ENGINE*8-1:0] m_axis_pipeline_tkeep;

genvar i;
generate
    for (i=0; i<NUM_ENGINE; i=i+1) begin : SHA_PARALLEL_PIPE // <-- example block name
        sha256_pipeline_secworks #( 
            .PIPE_INDEX(i),
            .DEBUG(DEBUG)
            )sha256_pipeline(
            .aclk ( aclk ),
            .aresetn ( aresetn ),
            .sha256_in_tvalid(m_axis_input_switch_tvalid[i]),
            .sha256_in_tlast(m_axis_input_switch_tlast[i]),
            .sha256_in_tready(m_axis_input_switch_tready[i]),
            .sha256_in_tdata(m_axis_input_switch_tdata[(i+1)*64-1:i*64]),
            .sha256_in_tkeep(m_axis_input_switch_tkeep[(i+1)*8-1:i*8]),
            .sha256_out_tvalid(m_axis_pipeline_tvalid[i]),
            .sha256_out_tlast(m_axis_pipeline_tlast[i]),
            .sha256_out_tready(m_axis_pipeline_tready[i]),
            .sha256_out_tdata(m_axis_pipeline_tdata[(i+1)*64-1:i*64]),
            .sha256_out_tkeep(m_axis_pipeline_tkeep[(i+1)*8-1:i*8])
        );
    end 
endgenerate


// round robin fetch hash value & results from pipelines, path 64 bits
AXI4S #(.AXI4S_DATA_BITS(64)) sha_output_swtich();
AXI4S #(.AXI4S_DATA_BITS(64)) sha_output_swtich_reg();


if (NUM_ENGINE == 1) begin
    assign sha_output_swtich.tvalid = m_axis_pipeline_tvalid;
    assign sha_output_swtich.tdata = m_axis_pipeline_tdata;
    assign sha_output_swtich.tkeep = m_axis_pipeline_tkeep;
    assign sha_output_swtich.tlast = m_axis_pipeline_tlast;
    assign m_axis_pipeline_tready = sha_output_swtich.tready;
end
else if (NUM_ENGINE == 2) begin
    axis_switch_width_64_2_to_1 axis_switch_width_64_2_to_1 (
        .aclk ( aclk ),
        .aresetn ( aresetn ),
        .s_axis_tready ( m_axis_pipeline_tready ),
        .m_axis_tready ( sha_output_swtich.tready ),
        .s_req_suppress ( '0 ),
        .s_axis_tvalid ( m_axis_pipeline_tvalid ),
        .s_axis_tdata ( m_axis_pipeline_tdata ),
        .s_axis_tkeep ( m_axis_pipeline_tkeep ),
        .s_axis_tlast ( m_axis_pipeline_tlast ),
        .m_axis_tvalid ( sha_output_swtich.tvalid ),
        .m_axis_tdata ( sha_output_swtich.tdata ),
        .m_axis_tkeep ( sha_output_swtich.tkeep ),
        .m_axis_tlast ( sha_output_swtich.tlast ),
        .s_decode_err ( )
    );
end
else if (NUM_ENGINE == 4) begin
    axis_switch_width_64_4_to_1 axis_switch_width_64_4_to_1 (
        .aclk ( aclk ),
        .aresetn ( aresetn ),
        .s_axis_tready ( m_axis_pipeline_tready ),
        .m_axis_tready ( sha_output_swtich.tready ),
        .s_req_suppress ( '0 ),
        .s_axis_tvalid ( m_axis_pipeline_tvalid ),
        .s_axis_tdata ( m_axis_pipeline_tdata ),
        .s_axis_tkeep ( m_axis_pipeline_tkeep ),
        .s_axis_tlast ( m_axis_pipeline_tlast ),
        .m_axis_tvalid ( sha_output_swtich.tvalid ),
        .m_axis_tdata ( sha_output_swtich.tdata ),
        .m_axis_tkeep ( sha_output_swtich.tkeep ),
        .m_axis_tlast ( sha_output_swtich.tlast ),
        .s_decode_err ( )
    );
end
else if (NUM_ENGINE == 6) begin
    axis_switch_width_64_6_to_1 axis_switch_width_64_6_to_1 (
        .aclk ( aclk ),
        .aresetn ( aresetn ),
        .s_axis_tready ( m_axis_pipeline_tready ),
        .m_axis_tready ( sha_output_swtich.tready ),
        .s_req_suppress ( '0 ),
        .s_axis_tvalid ( m_axis_pipeline_tvalid ),
        .s_axis_tdata ( m_axis_pipeline_tdata ),
        .s_axis_tkeep ( m_axis_pipeline_tkeep ),
        .s_axis_tlast ( m_axis_pipeline_tlast ),
        .m_axis_tvalid ( sha_output_swtich.tvalid ),
        .m_axis_tdata ( sha_output_swtich.tdata ),
        .m_axis_tkeep ( sha_output_swtich.tkeep ),
        .m_axis_tlast ( sha_output_swtich.tlast ),
        .s_decode_err ( )
    );
end
else if (NUM_ENGINE == 8) begin
    axis_switch_width_64_8_to_1 axis_switch_width_64_8_to_1 (
        .aclk ( aclk ),
        .aresetn ( aresetn ),
        .s_axis_tready ( m_axis_pipeline_tready ),
        .m_axis_tready ( sha_output_swtich.tready ),
        .s_req_suppress ( '0 ),
        .s_axis_tvalid ( m_axis_pipeline_tvalid ),
        .s_axis_tdata ( m_axis_pipeline_tdata ),
        .s_axis_tkeep ( m_axis_pipeline_tkeep ),
        .s_axis_tlast ( m_axis_pipeline_tlast ),
        .m_axis_tvalid ( sha_output_swtich.tvalid ),
        .m_axis_tdata ( sha_output_swtich.tdata ),
        .m_axis_tkeep ( sha_output_swtich.tkeep ),
        .m_axis_tlast ( sha_output_swtich.tlast ),
        .s_decode_err ( )
    );
end

axis_reg_array #(.N_STAGES(4), .DATA_BITS(64)) inst_sha_output_swtich_reg_array (.aclk(aclk), .aresetn(aresetn), .s_axis(sha_output_swtich), .m_axis(sha_output_swtich_reg));


logic                   m_axis_64_to_512_converter_tvalid;
logic                   m_axis_64_to_512_converter_tlast;
logic                   m_axis_64_to_512_converter_tready;
logic [511:0]           m_axis_64_to_512_converter_tdata;
logic [63:0]            m_axis_64_to_512_converter_tkeep;

// convert to 512 bit
axis_dwidth_converter_64_to_512 axis_dwidth_converter_64_to_512 (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( sha_output_swtich_reg.tready ),
    .m_axis_tready ( m_axis_64_to_512_converter_tready ),
    .s_axis_tvalid ( sha_output_swtich_reg.tvalid ),
    .s_axis_tdata ( sha_output_swtich_reg.tdata ),
    .s_axis_tkeep ( sha_output_swtich_reg.tkeep ),
    .s_axis_tlast ( sha_output_swtich_reg.tlast ),
    .m_axis_tvalid ( m_axis_64_to_512_converter_tvalid ),
    .m_axis_tdata ( m_axis_64_to_512_converter_tdata ),
    .m_axis_tkeep ( m_axis_64_to_512_converter_tkeep ),
    .m_axis_tlast ( m_axis_64_to_512_converter_tlast )
);

// buffer output hash, width 512 bits
axis_data_fifo_width_512_depth_128 sha256_output_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( m_axis_64_to_512_converter_tready ),
    .m_axis_tready ( sha256_out_tready ),
    .s_axis_tvalid ( m_axis_64_to_512_converter_tvalid ),
    .s_axis_tdata ( m_axis_64_to_512_converter_tdata ),
    .s_axis_tkeep ( m_axis_64_to_512_converter_tkeep ),
    .s_axis_tlast ( m_axis_64_to_512_converter_tlast ),
    .m_axis_tvalid ( sha256_out_tvalid ),
    .m_axis_tdata ( sha256_out_tdata ),
    .m_axis_tkeep ( sha256_out_tkeep ),
    .m_axis_tlast ( sha256_out_tlast )
);




endmodule
`default_nettype wire