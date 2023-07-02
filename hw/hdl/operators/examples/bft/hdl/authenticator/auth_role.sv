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

// Use the tuser side channel to distinguish whether input is key init stream or auth message stream
// tusr - 0: auth message stream - 1: auth key init stream
// the first word of the message contains header, containing index(dst) information: | Payload | Header |
// the output contains the tag, message payload and the header | Auth | Payload | Header |

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

    input wire                  auth_key_config_in_tvalid,
    input wire                  auth_key_config_in_tlast,
    output wire                 auth_key_config_in_tready,
    input wire [511:0]          auth_key_config_in_tdata,
    input wire [63:0]           auth_key_config_in_tkeep,

    // Clock and reset
    input  wire                 aclk,
    input  wire[0:0]            aresetn

);

// bcast module for the auth key config in
logic auth_key_config_bcast_tvalid;
logic auth_key_config_bcast_tready;
logic auth_key_config_bcast_tlast;
logic [512-1:0] auth_key_config_bcast_tdata;
logic [64-1:0] auth_key_config_bcast_tkeep;

logic auth_key_config_bcast_reg_tvalid;
logic auth_key_config_bcast_reg_tready;
logic auth_key_config_bcast_reg_tlast;
logic [512-1:0] auth_key_config_bcast_reg_tdata;
logic [64-1:0] auth_key_config_bcast_reg_tkeep;

auth_key_bcast_handler_ip auth_key_bcast_handler_inst(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .bcastInStream_TDATA(auth_key_config_in_tdata),
    .bcastInStream_TVALID(auth_key_config_in_tvalid),
    .bcastInStream_TREADY(auth_key_config_in_tready),
    .bcastInStream_TKEEP(auth_key_config_in_tkeep),
    .bcastInStream_TSTRB(0),
    .bcastInStream_TLAST(auth_key_config_in_tlast),
    .bcastOutStream_TDATA(auth_key_config_bcast_tdata),
    .bcastOutStream_TVALID(auth_key_config_bcast_tvalid),
    .bcastOutStream_TREADY(auth_key_config_bcast_tready),
    .bcastOutStream_TKEEP(auth_key_config_bcast_tkeep),
    .bcastOutStream_TSTRB(),
    .bcastOutStream_TLAST(auth_key_config_bcast_tlast),
    .bcast_factor_V(NUM_ENGINE)
);


axis_register_slice_width_512 reg_slice_512 (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tkeep ( auth_key_config_bcast_tkeep ),
    .s_axis_tlast ( auth_key_config_bcast_tlast ),
    .s_axis_tready ( auth_key_config_bcast_tready ),
    .s_axis_tvalid ( auth_key_config_bcast_tvalid ),
    .s_axis_tdata ( auth_key_config_bcast_tdata ),
    .m_axis_tkeep ( auth_key_config_bcast_reg_tkeep ),
    .m_axis_tlast ( auth_key_config_bcast_reg_tlast ),
    .m_axis_tready ( auth_key_config_bcast_reg_tready ),
    .m_axis_tvalid ( auth_key_config_bcast_reg_tvalid ),
    .m_axis_tdata ( auth_key_config_bcast_reg_tdata )
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

// Append user ID for key config stream and message stream
localparam integer NUM_S_AXI_SWITCH = 2;

logic [NUM_S_AXI_SWITCH-1:0] s_axis_tuser_switch_tvalid;
logic [NUM_S_AXI_SWITCH-1:0] s_axis_tuser_switch_tready;
logic [NUM_S_AXI_SWITCH-1:0] s_axis_tuser_switch_tlast;
logic [NUM_S_AXI_SWITCH-1:0] s_axis_tuser_switch_tuser;
logic [NUM_S_AXI_SWITCH*512-1:0] s_axis_tuser_switch_tdata;
logic [NUM_S_AXI_SWITCH*64-1:0] s_axis_tuser_switch_tkeep;

logic m_axis_tuser_switch_tvalid;
logic m_axis_tuser_switch_tready;
logic m_axis_tuser_switch_tlast;
logic m_axis_tuser_switch_tuser;
logic [512-1:0] m_axis_tuser_switch_tdata;
logic [64-1:0] m_axis_tuser_switch_tkeep;

assign s_axis_tuser_switch_tvalid[0] = m_axis_auth_input_fifo_tvalid;
assign s_axis_tuser_switch_tlast[0] = m_axis_auth_input_fifo_tlast;
assign s_axis_tuser_switch_tuser[0] = 0;
assign s_axis_tuser_switch_tdata[(0+1)*512-1:0*512] = m_axis_auth_input_fifo_tdata;
assign s_axis_tuser_switch_tkeep[(0+1)*64-1:0*64] = m_axis_auth_input_fifo_tkeep;
assign m_axis_auth_input_fifo_tready = s_axis_tuser_switch_tready[0];

assign s_axis_tuser_switch_tvalid[1] =auth_key_config_bcast_reg_tvalid;
assign s_axis_tuser_switch_tlast[1] =auth_key_config_bcast_reg_tlast;
assign s_axis_tuser_switch_tuser[1] = 1;
assign s_axis_tuser_switch_tdata[(1+1)*512-1:1*512] =auth_key_config_bcast_reg_tdata;
assign s_axis_tuser_switch_tkeep[(1+1)*64-1:1*64] =auth_key_config_bcast_reg_tkeep;
assign auth_key_config_bcast_reg_tready = s_axis_tuser_switch_tready[1];

axis_switch_tuser_width_512_2_to_1 axis_switch_tuser_width_512_2_to_1_inst
(
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( s_axis_tuser_switch_tready ),
    .m_axis_tready ( m_axis_tuser_switch_tready ),
    .s_req_suppress ( '0 ),
    .s_axis_tvalid ( s_axis_tuser_switch_tvalid ),
    .s_axis_tdata ( s_axis_tuser_switch_tdata ),
    .s_axis_tkeep ( s_axis_tuser_switch_tkeep ),
    .s_axis_tlast ( s_axis_tuser_switch_tlast ),
    .s_axis_tuser ( s_axis_tuser_switch_tuser ),
    .m_axis_tvalid ( m_axis_tuser_switch_tvalid ),
    .m_axis_tdata ( m_axis_tuser_switch_tdata ),
    .m_axis_tkeep ( m_axis_tuser_switch_tkeep ),
    .m_axis_tlast ( m_axis_tuser_switch_tlast ),
    .m_axis_tuser ( m_axis_tuser_switch_tuser ),
    .s_decode_err ( )
);


// Forward the input stream to parallel engines
// For config stream, the same configuration information is forwarded multiple times and multiplexed to different engines
// The config information should be sent NUM_ENGINE times
localparam integer NUM_ENGINE_BITS = $clog2(NUM_ENGINE);

logic [NUM_ENGINE-1:0] m_axis_input_switch_tvalid;
logic [NUM_ENGINE-1:0] m_axis_input_switch_tready;
logic [NUM_ENGINE-1:0] m_axis_input_switch_tlast;
logic [NUM_ENGINE-1:0] m_axis_input_switch_tuser;
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
        s_axis_input_switch_tdest_message <= '0;
        s_axis_input_switch_tdest_config <= '0;
    end
    else begin
        if (m_axis_tuser_switch_tready & m_axis_tuser_switch_tvalid & m_axis_tuser_switch_tlast & (m_axis_tuser_switch_tuser == 0)) begin
            s_axis_input_switch_tdest_message <= s_axis_input_switch_tdest_message + 1;
            if (s_axis_input_switch_tdest_message == num_engine_reg - 1) begin
                s_axis_input_switch_tdest_message <= '0;
            end
        end

        if (m_axis_tuser_switch_tready & m_axis_tuser_switch_tvalid & m_axis_tuser_switch_tlast & (m_axis_tuser_switch_tuser == 1)) begin
            s_axis_input_switch_tdest_config <= s_axis_input_switch_tdest_config + 1;
            if (s_axis_input_switch_tdest_config == NUM_ENGINE - 1) begin
                s_axis_input_switch_tdest_config <= '0;
            end
        end

    end 
end

assign s_axis_input_switch_tdest = (m_axis_tuser_switch_tuser == 0) ? s_axis_input_switch_tdest_message : s_axis_input_switch_tdest_config;

if (NUM_ENGINE == 1) begin
    assign m_axis_input_switch_tvalid = m_axis_tuser_switch_tvalid;
    assign m_axis_input_switch_tdata = m_axis_tuser_switch_tdata;
    assign m_axis_input_switch_tkeep = m_axis_tuser_switch_tkeep;
    assign m_axis_input_switch_tlast = m_axis_tuser_switch_tlast;
    assign m_axis_tuser_switch_tready = m_axis_input_switch_tready;
    assign m_axis_input_switch_tuser = m_axis_tuser_switch_tuser;
end
else if (NUM_ENGINE == 2) begin
    axis_switch_tuser_width_512_1_to_2 axis_switch_tuser_width_512_1_to_2_inst (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( m_axis_tuser_switch_tready ),
    .m_axis_tready ( m_axis_input_switch_tready ),
    .s_axis_tvalid ( m_axis_tuser_switch_tvalid ),
    .s_axis_tdata ( m_axis_tuser_switch_tdata ),
    .s_axis_tkeep ( m_axis_tuser_switch_tkeep ),
    .s_axis_tlast ( m_axis_tuser_switch_tlast ),
    .s_axis_tuser ( m_axis_tuser_switch_tuser ),
    .s_axis_tdest ( s_axis_input_switch_tdest ),
    .m_axis_tvalid ( m_axis_input_switch_tvalid ),
    .m_axis_tdata ( m_axis_input_switch_tdata ),
    .m_axis_tkeep ( m_axis_input_switch_tkeep ),
    .m_axis_tlast ( m_axis_input_switch_tlast ),
    .m_axis_tuser ( m_axis_input_switch_tuser ),
    .m_axis_tdest ( m_axis_input_switch_tdest ),
    .s_decode_err ( )
    );
end
else if (NUM_ENGINE == 4) begin
    axis_switch_tuser_width_512_1_to_4 axis_switch_tuser_width_512_1_to_4_inst (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( m_axis_tuser_switch_tready ),
    .m_axis_tready ( m_axis_input_switch_tready ),
    .s_axis_tvalid ( m_axis_tuser_switch_tvalid ),
    .s_axis_tdata ( m_axis_tuser_switch_tdata ),
    .s_axis_tkeep ( m_axis_tuser_switch_tkeep ),
    .s_axis_tlast ( m_axis_tuser_switch_tlast ),
    .s_axis_tuser ( m_axis_tuser_switch_tuser ),
    .s_axis_tdest ( s_axis_input_switch_tdest ),
    .m_axis_tvalid ( m_axis_input_switch_tvalid ),
    .m_axis_tdata ( m_axis_input_switch_tdata ),
    .m_axis_tkeep ( m_axis_input_switch_tkeep ),
    .m_axis_tlast ( m_axis_input_switch_tlast ),
    .m_axis_tuser ( m_axis_input_switch_tuser ),
    .m_axis_tdest ( m_axis_input_switch_tdest ),
    .s_decode_err ( )
    );
end
else if (NUM_ENGINE == 8) begin
    axis_switch_tuser_width_512_1_to_8 axis_switch_tuser_width_512_1_to_8_inst (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( m_axis_tuser_switch_tready ),
    .m_axis_tready ( m_axis_input_switch_tready ),
    .s_axis_tvalid ( m_axis_tuser_switch_tvalid ),
    .s_axis_tdata ( m_axis_tuser_switch_tdata ),
    .s_axis_tkeep ( m_axis_tuser_switch_tkeep ),
    .s_axis_tlast ( m_axis_tuser_switch_tlast ),
    .s_axis_tuser ( m_axis_tuser_switch_tuser ),
    .s_axis_tdest ( s_axis_input_switch_tdest ),
    .m_axis_tvalid ( m_axis_input_switch_tvalid ),
    .m_axis_tdata ( m_axis_input_switch_tdata ),
    .m_axis_tkeep ( m_axis_input_switch_tkeep ),
    .m_axis_tlast ( m_axis_input_switch_tlast ),
    .m_axis_tuser ( m_axis_input_switch_tuser ),
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
            .DEBUG(DEBUG),
            .VERIFICATION(VERIFICATION)
        )auth_pipe(
            .aclk ( aclk ),
            .aresetn ( aresetn ),
            .auth_in_tvalid(m_axis_input_switch_tvalid[i]),
            .auth_in_tlast(m_axis_input_switch_tlast[i]),
            .auth_in_tuser(m_axis_input_switch_tuser[i]),
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
