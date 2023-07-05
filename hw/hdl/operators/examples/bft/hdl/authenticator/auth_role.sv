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
import bftTypes::*;

// the first word of the message contains header, containing index(dst) information: | Payload | Header |

module auth_role #( 
  parameter integer NUM_ENGINE = 4,
  parameter integer VERIFICATION = 0
)
(
    
    input wire [7:0]            num_engine,

    input wire                  auth_in_tvalid,
    input wire                  auth_in_tlast,
    output wire                 auth_in_tready,
    input wire [511:0]          auth_in_tdata,
    input wire [63:0]           auth_in_tkeep,

    output wire                 auth_out_tvalid,
    output wire                 auth_out_tlast,
    input wire                  auth_out_tready,
    output wire [511:0]         auth_out_tdata,
    output wire [63:0]          auth_out_tkeep,

    // Clock and reset
    input  wire                 aclk,
    input  wire[0:0]            aresetn

);

// fifo for the auth encrypt in
logic m_axis_auth_input_fifo_tvalid;
logic m_axis_auth_input_fifo_tready;
logic m_axis_auth_input_fifo_tlast;
logic [512-1:0] m_axis_auth_input_fifo_tdata;
logic [64-1:0] m_axis_auth_input_fifo_tkeep;

axis_data_fifo_width_512_depth_128 auth_role_input_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( auth_in_tready ),
    .m_axis_tready ( m_axis_auth_input_fifo_tready ),
    .s_axis_tvalid ( auth_in_tvalid ),
    .s_axis_tdata ( auth_in_tdata ),
    .s_axis_tkeep ( auth_in_tkeep ),
    .s_axis_tlast ( auth_in_tlast ),
    .m_axis_tvalid ( m_axis_auth_input_fifo_tvalid ),
    .m_axis_tdata ( m_axis_auth_input_fifo_tdata ),
    .m_axis_tkeep ( m_axis_auth_input_fifo_tkeep ),
    .m_axis_tlast ( m_axis_auth_input_fifo_tlast )
);


// Forward the input stream to parallel engines
// For config stream, the same configuration information is forwarded multiple times and multiplexed to different engines
// The config information should be sent NUM_ENGINE times
localparam integer NUM_ENGINE_BITS = $clog2(NUM_ENGINE);

logic [NUM_ENGINE-1:0] m_axis_input_switch_tvalid;
logic [NUM_ENGINE-1:0] m_axis_input_switch_tready;
logic [NUM_ENGINE-1:0] m_axis_input_switch_tlast;
logic [NUM_ENGINE*512-1:0] m_axis_input_switch_tdata;
logic [NUM_ENGINE*64-1:0] m_axis_input_switch_tkeep;
logic [NUM_ENGINE*NUM_ENGINE_BITS-1:0] m_axis_input_switch_tdest;

logic [NUM_ENGINE_BITS-1:0] s_axis_input_switch_tdest;
logic [NUM_ENGINE_BITS-1:0] s_axis_input_switch_tdest_message;
logic [NUM_ENGINE_BITS-1:0] s_axis_input_switch_tdest_config;

logic [7:0] num_engine_reg;
logic [7:0] num_engine_reg2;

always_ff @( posedge aclk ) begin 
    num_engine_reg <= num_engine;
    num_engine_reg2 <= num_engine_reg;
end

always_ff @( posedge aclk ) begin 
    if (~aresetn) begin
        s_axis_input_switch_tdest <= '0;
    end
    else begin
        if (m_axis_auth_input_fifo_tready & m_axis_auth_input_fifo_tvalid & m_axis_auth_input_fifo_tlast) begin
            s_axis_input_switch_tdest <= s_axis_input_switch_tdest + 1;
            if (s_axis_input_switch_tdest == num_engine_reg - 1) begin
                s_axis_input_switch_tdest <= '0;
            end
        end
    end 
end

if (NUM_ENGINE == 1) begin
    assign m_axis_input_switch_tvalid = m_axis_auth_input_fifo_tvalid;
    assign m_axis_input_switch_tdata = m_axis_auth_input_fifo_tdata;
    assign m_axis_input_switch_tkeep = m_axis_auth_input_fifo_tkeep;
    assign m_axis_input_switch_tlast = m_axis_auth_input_fifo_tlast;
    assign m_axis_auth_input_fifo_tready = m_axis_input_switch_tready;
end
else if (NUM_ENGINE == 2) begin
    axis_switch_width_512_1_to_2 axis_switch_width_512_1_to_2_inst (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( m_axis_auth_input_fifo_tready ),
    .m_axis_tready ( m_axis_input_switch_tready ),
    .s_axis_tvalid ( m_axis_auth_input_fifo_tvalid ),
    .s_axis_tdata ( m_axis_auth_input_fifo_tdata ),
    .s_axis_tkeep ( m_axis_auth_input_fifo_tkeep ),
    .s_axis_tlast ( m_axis_auth_input_fifo_tlast ),
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
    axis_switch_width_512_1_to_4 axis_switch_width_512_1_to_4_inst (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( m_axis_auth_input_fifo_tready ),
    .m_axis_tready ( m_axis_input_switch_tready ),
    .s_axis_tvalid ( m_axis_auth_input_fifo_tvalid ),
    .s_axis_tdata ( m_axis_auth_input_fifo_tdata ),
    .s_axis_tkeep ( m_axis_auth_input_fifo_tkeep ),
    .s_axis_tlast ( m_axis_auth_input_fifo_tlast ),
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
    axis_switch_width_512_1_to_8 axis_switch_width_512_1_to_8_inst (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( m_axis_auth_input_fifo_tready ),
    .m_axis_tready ( m_axis_input_switch_tready ),
    .s_axis_tvalid ( m_axis_auth_input_fifo_tvalid ),
    .s_axis_tdata ( m_axis_auth_input_fifo_tdata ),
    .s_axis_tkeep ( m_axis_auth_input_fifo_tkeep ),
    .s_axis_tlast ( m_axis_auth_input_fifo_tlast ),
    .s_axis_tdest ( s_axis_input_switch_tdest ),
    .m_axis_tvalid ( m_axis_input_switch_tvalid ),
    .m_axis_tdata ( m_axis_input_switch_tdata ),
    .m_axis_tkeep ( m_axis_input_switch_tkeep ),
    .m_axis_tlast ( m_axis_input_switch_tlast ),
    .m_axis_tdest ( m_axis_input_switch_tdest ),
    .s_decode_err ( )
    );
end

logic [NUM_ENGINE-1:0] m_axis_pipeline_tvalid;
logic [NUM_ENGINE-1:0] m_axis_pipeline_tready;
logic [NUM_ENGINE-1:0] m_axis_pipeline_tlast;
logic [NUM_ENGINE*512-1:0] m_axis_pipeline_tdata;
logic [NUM_ENGINE*64-1:0] m_axis_pipeline_tkeep;

genvar i;
generate
    for (i=0; i<NUM_ENGINE; i=i+1) begin : AUTH_PARALLEL_PIPE // <-- example block name
        auth_pipe #( 
            .PIPE_INDEX(i),
            .VERIFICATION(VERIFICATION)
        )auth_pipe(
            .aclk ( aclk ),
            .aresetn ( aresetn ),
            .auth_in_tvalid(m_axis_input_switch_tvalid[i]),
            .auth_in_tlast(m_axis_input_switch_tlast[i]),
            .auth_in_tready(m_axis_input_switch_tready[i]),
            .auth_in_tdata(m_axis_input_switch_tdata[(i+1)*512-1:i*512]),
            .auth_in_tkeep(m_axis_input_switch_tkeep[(i+1)*64-1:i*64]),
            .auth_out_tvalid(m_axis_pipeline_tvalid[i]),
            .auth_out_tlast(m_axis_pipeline_tlast[i]),
            .auth_out_tready(m_axis_pipeline_tready[i]),
            .auth_out_tdata(m_axis_pipeline_tdata[(i+1)*512-1:i*512]),
            .auth_out_tkeep(m_axis_pipeline_tkeep[(i+1)*64-1:i*64])
        );
    end 
endgenerate

logic [7:0] output_pipe_index;

always @(posedge aclk) begin
    if (~aresetn) begin
        output_pipe_index <= '0;
    end
    else begin
        if (m_axis_pipeline_tvalid[output_pipe_index] & m_axis_pipeline_tready[output_pipe_index] & m_axis_pipeline_tlast[output_pipe_index]) begin
            output_pipe_index <= output_pipe_index + 1'b1;
            if (output_pipe_index == num_engine_reg2 - 1) begin
                output_pipe_index <= '0;
            end
        end
    end
end


logic [NUM_ENGINE-1:0] s_req_suppress;
assign s_req_suppress = '0;

logic m_axis_output_switch_tvalid;
logic m_axis_output_switch_tready;
logic m_axis_output_switch_tlast;
logic [512-1:0] m_axis_output_switch_tdata;
logic [64-1:0] m_axis_output_switch_tkeep;

if (NUM_ENGINE == 1) begin
    assign m_axis_output_switch_tvalid = m_axis_pipeline_tvalid;
    assign m_axis_output_switch_tdata = m_axis_pipeline_tdata;
    assign m_axis_output_switch_tkeep = m_axis_pipeline_tkeep;
    assign m_axis_output_switch_tlast = m_axis_pipeline_tlast;
    assign m_axis_pipeline_tready = m_axis_output_switch_tready;
end
else if (NUM_ENGINE == 2) begin
    axis_switch_width_512_2_to_1 axis_switch_width_512_2_to_1_inst (
        .aclk ( aclk ),
        .aresetn ( aresetn ),
        .s_axis_tready ( m_axis_pipeline_tready ),
        .m_axis_tready ( m_axis_output_switch_tready ),
        .s_req_suppress ( s_req_suppress ),
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
else if (NUM_ENGINE == 4) begin
    axis_switch_width_512_4_to_1 axis_switch_width_512_4_to_1_inst (
        .aclk ( aclk ),
        .aresetn ( aresetn ),
        .s_axis_tready ( m_axis_pipeline_tready ),
        .m_axis_tready ( m_axis_output_switch_tready ),
        .s_req_suppress ( s_req_suppress ),
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
else if (NUM_ENGINE == 8) begin
    axis_switch_width_512_8_to_1 axis_switch_width_512_8_to_1_inst (
        .aclk ( aclk ),
        .aresetn ( aresetn ),
        .s_axis_tready ( m_axis_pipeline_tready ),
        .m_axis_tready ( m_axis_output_switch_tready ),
        .s_req_suppress ( s_req_suppress ),
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

axis_data_fifo_width_512_depth_16 auth_role_output_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( m_axis_output_switch_tready ),
    .m_axis_tready ( auth_out_tready ),
    .s_axis_tvalid ( m_axis_output_switch_tvalid ),
    .s_axis_tdata ( m_axis_output_switch_tdata ),
    .s_axis_tkeep ( m_axis_output_switch_tkeep ),
    .s_axis_tlast ( m_axis_output_switch_tlast ),
    .m_axis_tvalid ( auth_out_tvalid ),
    .m_axis_tdata ( auth_out_tdata ),
    .m_axis_tkeep ( auth_out_tkeep ),
    .m_axis_tlast ( auth_out_tlast )
);

`ifdef DEBUG_AUTH_ROLE
    ila_auth_role ila_auth_role
    (
        .clk(aclk), // input wire clk
        .probe0(m_axis_input_switch_tvalid),  //8
        .probe1(m_axis_input_switch_tready), //8
        .probe2(m_axis_input_switch_tlast), //8
        .probe3(m_axis_pipeline_tvalid),  //8
        .probe4(m_axis_pipeline_tready), //8
        .probe5(m_axis_pipeline_tlast), //8
        .probe6(output_pipe_index), //8
        .probe7(s_req_suppress) // 8
    );
`endif

endmodule
