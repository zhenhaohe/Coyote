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

module sha256_role #( 
    parameter integer  NUM_CLUSTER = 4,
    parameter integer  NUM_ENGINE_PER_CLUSTER = 8,
    parameter integer  DEBUG = 0
)
(
    input wire [7:0]            num_sha_cluster,
    input wire [7:0]            num_engine_per_cluster,

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

// multiplex the 512 bit data path to different sha clusters
localparam integer NUM_CLUSTER_BITS = $clog2(NUM_CLUSTER);

logic [NUM_CLUSTER-1:0] m_axis_input_switch_tvalid;
logic [NUM_CLUSTER-1:0] m_axis_input_switch_tready;
logic [NUM_CLUSTER-1:0] m_axis_input_switch_tlast;
logic [NUM_CLUSTER*512-1:0] m_axis_input_switch_tdata;
logic [NUM_CLUSTER*64-1:0] m_axis_input_switch_tkeep;
logic [NUM_CLUSTER*NUM_CLUSTER_BITS-1:0] m_axis_input_switch_tdest;

logic [NUM_CLUSTER_BITS-1:0] s_axis_input_switch_tdest;


logic [7:0] num_sha_cluster_reg;
logic [7:0] num_engine_per_cluster_reg;

always_ff @( posedge aclk ) begin 
    num_sha_cluster_reg <= num_sha_cluster;
    num_engine_per_cluster_reg <= num_engine_per_cluster;
end

always_ff @( posedge aclk ) begin 
    if (~aresetn) begin
        s_axis_input_switch_tdest <= '0;
    end
    else begin
        if (m_axis_input_fifo_tready & m_axis_input_fifo_tvalid & m_axis_input_fifo_tlast) begin
            s_axis_input_switch_tdest <= s_axis_input_switch_tdest + 1;
            if (s_axis_input_switch_tdest == num_sha_cluster_reg - 1) begin
                s_axis_input_switch_tdest <= '0;
            end
        end
    end 
end

if (NUM_CLUSTER == 1) begin
    assign m_axis_input_switch_tvalid = m_axis_input_fifo_tvalid;
    assign m_axis_input_switch_tdata = m_axis_input_fifo_tdata;
    assign m_axis_input_switch_tkeep = m_axis_input_fifo_tkeep;
    assign m_axis_input_switch_tlast = m_axis_input_fifo_tlast;
    assign m_axis_input_fifo_tready = m_axis_input_switch_tready;
end
else if (NUM_CLUSTER == 2) begin
    axis_switch_width_512_1_to_2 axis_switch_width_512_1_to_2_inst (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( m_axis_input_fifo_tready ),
    .m_axis_tready ( m_axis_input_switch_tready ),
    .s_axis_tvalid ( m_axis_input_fifo_tvalid ),
    .s_axis_tdata ( m_axis_input_fifo_tdata ),
    .s_axis_tkeep ( m_axis_input_fifo_tkeep ),
    .s_axis_tlast ( m_axis_input_fifo_tlast ),
    .s_axis_tdest ( s_axis_input_switch_tdest ),
    .m_axis_tvalid ( m_axis_input_switch_tvalid ),
    .m_axis_tdata ( m_axis_input_switch_tdata ),
    .m_axis_tkeep ( m_axis_input_switch_tkeep ),
    .m_axis_tlast ( m_axis_input_switch_tlast ),
    .m_axis_tdest ( m_axis_input_switch_tdest ),
    .s_decode_err ( )
    );
end
else if (NUM_CLUSTER == 4) begin
    axis_switch_width_512_1_to_4 axis_switch_width_512_1_to_4_inst (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( m_axis_input_fifo_tready ),
    .m_axis_tready ( m_axis_input_switch_tready ),
    .s_axis_tvalid ( m_axis_input_fifo_tvalid ),
    .s_axis_tdata ( m_axis_input_fifo_tdata ),
    .s_axis_tkeep ( m_axis_input_fifo_tkeep ),
    .s_axis_tlast ( m_axis_input_fifo_tlast ),
    .s_axis_tdest ( s_axis_input_switch_tdest ),
    .m_axis_tvalid ( m_axis_input_switch_tvalid ),
    .m_axis_tdata ( m_axis_input_switch_tdata ),
    .m_axis_tkeep ( m_axis_input_switch_tkeep ),
    .m_axis_tlast ( m_axis_input_switch_tlast ),
    .m_axis_tdest ( m_axis_input_switch_tdest ),
    .s_decode_err ( )
    );
end
else if (NUM_CLUSTER == 5) begin
    axis_switch_width_512_1_to_5 axis_switch_width_512_1_to_5_inst (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( m_axis_input_fifo_tready ),
    .m_axis_tready ( m_axis_input_switch_tready ),
    .s_axis_tvalid ( m_axis_input_fifo_tvalid ),
    .s_axis_tdata ( m_axis_input_fifo_tdata ),
    .s_axis_tkeep ( m_axis_input_fifo_tkeep ),
    .s_axis_tlast ( m_axis_input_fifo_tlast ),
    .s_axis_tdest ( s_axis_input_switch_tdest ),
    .m_axis_tvalid ( m_axis_input_switch_tvalid ),
    .m_axis_tdata ( m_axis_input_switch_tdata ),
    .m_axis_tkeep ( m_axis_input_switch_tkeep ),
    .m_axis_tlast ( m_axis_input_switch_tlast ),
    .m_axis_tdest ( m_axis_input_switch_tdest ),
    .s_decode_err ( )
    );
end
else if (NUM_CLUSTER == 8) begin
    axis_switch_width_512_1_to_8 axis_switch_width_512_1_to_8_inst (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( m_axis_input_fifo_tready ),
    .m_axis_tready ( m_axis_input_switch_tready ),
    .s_axis_tvalid ( m_axis_input_fifo_tvalid ),
    .s_axis_tdata ( m_axis_input_fifo_tdata ),
    .s_axis_tkeep ( m_axis_input_fifo_tkeep ),
    .s_axis_tlast ( m_axis_input_fifo_tlast ),
    .s_axis_tdest ( s_axis_input_switch_tdest ),
    .m_axis_tvalid ( m_axis_input_switch_tvalid ),
    .m_axis_tdata ( m_axis_input_switch_tdata ),
    .m_axis_tkeep ( m_axis_input_switch_tkeep ),
    .m_axis_tlast ( m_axis_input_switch_tlast ),
    .m_axis_tdest ( m_axis_input_switch_tdest ),
    .s_decode_err ( )
    );
end

// instantiate multiple sha clusters
// input data path 512, output hash data path 512 
logic [NUM_CLUSTER-1:0] m_axis_pipeline_tvalid;
logic [NUM_CLUSTER-1:0] m_axis_pipeline_tready;
logic [NUM_CLUSTER-1:0] m_axis_pipeline_tlast;
logic [NUM_CLUSTER*512-1:0] m_axis_pipeline_tdata;
logic [NUM_CLUSTER*64-1:0] m_axis_pipeline_tkeep;

genvar i;
generate
    for (i=0; i<NUM_CLUSTER; i=i+1) begin : SHA_PARALLEL_CLUSTER // <-- example block name
        sha256_cluster #( 
        .NUM_ENGINE(NUM_ENGINE_PER_CLUSTER),
        .DEBUG((DEBUG==1) & (i==0))
        )sha256_cluster(
            .aclk ( aclk ),
            .aresetn ( aresetn ),
            .num_engine (num_engine_per_cluster_reg),
            .sha256_in_tvalid(m_axis_input_switch_tvalid[i]),
            .sha256_in_tlast(m_axis_input_switch_tlast[i]),
            .sha256_in_tready(m_axis_input_switch_tready[i]),
            .sha256_in_tdata(m_axis_input_switch_tdata[(i+1)*512-1:i*512]),
            .sha256_in_tkeep(m_axis_input_switch_tkeep[(i+1)*64-1:i*64]),
            .sha256_out_tvalid(m_axis_pipeline_tvalid[i]),
            .sha256_out_tlast(m_axis_pipeline_tlast[i]),
            .sha256_out_tready(m_axis_pipeline_tready[i]),
            .sha256_out_tdata(m_axis_pipeline_tdata[(i+1)*512-1:i*512]),
            .sha256_out_tkeep(m_axis_pipeline_tkeep[(i+1)*64-1:i*64])
        );
    end 
endgenerate

// Round-robin fetch the hash value from each sha cluster
logic m_axis_output_switch_tvalid;
logic m_axis_output_switch_tready;
logic m_axis_output_switch_tlast;
logic [512-1:0] m_axis_output_switch_tdata;
logic [64-1:0] m_axis_output_switch_tkeep;

if (NUM_CLUSTER == 1) begin
    assign m_axis_output_switch_tvalid = m_axis_pipeline_tvalid;
    assign m_axis_output_switch_tdata = m_axis_pipeline_tdata;
    assign m_axis_output_switch_tkeep = m_axis_pipeline_tkeep;
    assign m_axis_output_switch_tlast = m_axis_pipeline_tlast;
    assign m_axis_pipeline_tready = m_axis_output_switch_tready;
end
else if (NUM_CLUSTER == 2) begin
    axis_switch_width_512_2_to_1 axis_switch_width_512_2_to_1 (
        .aclk ( aclk ),
        .aresetn ( aresetn ),
        .s_axis_tready ( m_axis_pipeline_tready ),
        .m_axis_tready ( m_axis_output_switch_tready ),
        .s_req_suppress ( '0 ),
        .s_axis_tvalid ( m_axis_pipeline_tvalid ),
        .s_axis_tdata ( m_axis_pipeline_tdata ),
        .s_axis_tkeep ( m_axis_pipeline_tkeep ),
        .s_axis_tlast ( m_axis_pipeline_tlast ),
        .m_axis_tvalid ( m_axis_output_switch_tvalid ),
        .m_axis_tdata ( m_axis_output_switch_tdata ),
        .m_axis_tkeep ( m_axis_output_switch_tkeep ),
        .m_axis_tlast ( m_axis_output_switch_tlast ),
        .s_decode_err ( )
    );
end
else if (NUM_CLUSTER == 4) begin
    axis_switch_width_512_4_to_1 axis_switch_width_512_4_to_1 (
        .aclk ( aclk ),
        .aresetn ( aresetn ),
        .s_axis_tready ( m_axis_pipeline_tready ),
        .m_axis_tready ( m_axis_output_switch_tready ),
        .s_req_suppress ( '0 ),
        .s_axis_tvalid ( m_axis_pipeline_tvalid ),
        .s_axis_tdata ( m_axis_pipeline_tdata ),
        .s_axis_tkeep ( m_axis_pipeline_tkeep ),
        .s_axis_tlast ( m_axis_pipeline_tlast ),
        .m_axis_tvalid ( m_axis_output_switch_tvalid ),
        .m_axis_tdata ( m_axis_output_switch_tdata ),
        .m_axis_tkeep ( m_axis_output_switch_tkeep ),
        .m_axis_tlast ( m_axis_output_switch_tlast ),
        .s_decode_err ( )
    );
end
else if (NUM_CLUSTER == 5) begin
    axis_switch_width_512_5_to_1 axis_switch_width_512_5_to_1 (
        .aclk ( aclk ),
        .aresetn ( aresetn ),
        .s_axis_tready ( m_axis_pipeline_tready ),
        .m_axis_tready ( m_axis_output_switch_tready ),
        .s_req_suppress ( '0 ),
        .s_axis_tvalid ( m_axis_pipeline_tvalid ),
        .s_axis_tdata ( m_axis_pipeline_tdata ),
        .s_axis_tkeep ( m_axis_pipeline_tkeep ),
        .s_axis_tlast ( m_axis_pipeline_tlast ),
        .m_axis_tvalid ( m_axis_output_switch_tvalid ),
        .m_axis_tdata ( m_axis_output_switch_tdata ),
        .m_axis_tkeep ( m_axis_output_switch_tkeep ),
        .m_axis_tlast ( m_axis_output_switch_tlast ),
        .s_decode_err ( )
    );
end
else if (NUM_CLUSTER == 8) begin
    axis_switch_width_512_8_to_1 axis_switch_width_512_8_to_1 (
        .aclk ( aclk ),
        .aresetn ( aresetn ),
        .s_axis_tready ( m_axis_pipeline_tready ),
        .m_axis_tready ( m_axis_output_switch_tready ),
        .s_req_suppress ( '0 ),
        .s_axis_tvalid ( m_axis_pipeline_tvalid ),
        .s_axis_tdata ( m_axis_pipeline_tdata ),
        .s_axis_tkeep ( m_axis_pipeline_tkeep ),
        .s_axis_tlast ( m_axis_pipeline_tlast ),
        .m_axis_tvalid ( m_axis_output_switch_tvalid ),
        .m_axis_tdata ( m_axis_output_switch_tdata ),
        .m_axis_tkeep ( m_axis_output_switch_tkeep ),
        .m_axis_tlast ( m_axis_output_switch_tlast ),
        .s_decode_err ( )
    );
end

// buffer the output hash value
logic sha256_output_fifo_tvalid;
logic sha256_output_fifo_tready;
logic sha256_output_fifo_tlast;
logic [512-1:0] sha256_output_fifo_tdata;
logic [64-1:0] sha256_output_fifo_tkeep;

axis_data_fifo_width_512_depth_16 sha256_output_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( m_axis_output_switch_tready ),
    .m_axis_tready ( sha256_output_fifo_tready ),
    .s_axis_tvalid ( m_axis_output_switch_tvalid ),
    .s_axis_tdata ( m_axis_output_switch_tdata ),
    .s_axis_tkeep ( m_axis_output_switch_tkeep ),
    .s_axis_tlast ( m_axis_output_switch_tlast ),
    .m_axis_tvalid ( sha256_output_fifo_tvalid ),
    .m_axis_tdata ( sha256_output_fifo_tdata ),
    .m_axis_tkeep ( sha256_output_fifo_tkeep ),
    .m_axis_tlast ( sha256_output_fifo_tlast )
);

assign sha256_out_tvalid = sha256_output_fifo_tvalid;
assign sha256_out_tlast = sha256_output_fifo_tlast;
assign sha256_output_fifo_tready = sha256_out_tready; 
assign sha256_out_tdata = sha256_output_fifo_tdata;
assign sha256_out_tkeep = sha256_output_fifo_tkeep;

endmodule
`default_nettype wire