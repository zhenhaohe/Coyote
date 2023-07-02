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

// TODO: add the verification path
// Current code perform the auth but doesn't append the auth to the msg and doesn't perform the check
module auth_pipe
#( 
    parameter integer PIPE_INDEX = 0,
    parameter integer VERIFICATION = 0
)
(
    
    AXI4SR.s                    auth_in,
    AXI4S.m                     auth_out,

    // Clock and reset
    input  wire                 aclk,
    input  wire[0:0]            aresetn

);

AXI4SR #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) auth_in_s0();

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) s_axis_msg_input_fifo();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) m_axis_msg_input_fifo();

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) auth_msg_s0();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) auth_msg_s1();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) auth_msg_s2();
AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) auth_msg_s3();

metaIntf #(.STYPE(logic[64-1:0])) auth_meta_s0();

AXI4S #(.AXI4S_DATA_BITS(32)) auth_msg_w32_s0();
AXI4S #(.AXI4S_DATA_BITS(32)) auth_msg_w32_s1();

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) axis_key_config_w512();

metaIntf #(.STYPE(logic[256-1:0])) key_config_w256();

metaIntf #(.STYPE(logic[256-1:0])) auth_hsh();

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) auth_out_s0();

// register input
axisr_reg_array #(.N_STAGES(3)) inst_auth_in_reg_array (.aclk(aclk), .aresetn(aresetn), .s_axis(auth_in), .m_axis(auth_in_s0));


// Use the tid side channel to distinguish whether input is key init stream or auth message stream
// tid - 0: auth message stream - 1: auth key init stream
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
	.s_axis_tready ( auth_in_s0.tready ),
	.m_axis_tready ( m_axis_input_switch_tready ),
	.s_axis_tvalid ( auth_in_s0.tvalid ),
	.s_axis_tdata ( auth_in_s0.tdata ),
	.s_axis_tkeep ( auth_in_s0.tkeep ),
	.s_axis_tlast ( auth_in_s0.tlast ),
	.s_axis_tdest ( auth_in_s0.tid ), // use tid as the dest signal for the axi switch
	.m_axis_tvalid ( m_axis_input_switch_tvalid ),
	.m_axis_tdata ( m_axis_input_switch_tdata ),
	.m_axis_tkeep ( m_axis_input_switch_tkeep ),
	.m_axis_tlast ( m_axis_input_switch_tlast ),
	.m_axis_tdest ( m_axis_input_switch_tdest ),
	.s_decode_err ( )
);

// auth message stream pipeline
// tid - 0: auth message stream
// the first word of the message contains header, containing index&len information: | Payload | Header |
// the index&len information are queued in very small fifos
// the message payload is converted from 512 bits to 32 bits block for auth module


assign s_axis_msg_input_fifo.tvalid = m_axis_input_switch_tvalid[0];
assign m_axis_input_switch_tready[0] = s_axis_msg_input_fifo.tready;
assign s_axis_msg_input_fifo.tlast = m_axis_input_switch_tlast[0];
assign s_axis_msg_input_fifo.tdata = m_axis_input_switch_tdata[(0+1)*512-1:0*512];
assign s_axis_msg_input_fifo.tkeep = m_axis_input_switch_tkeep[(0+1)*64-1:0*64];

axis_data_fifo_width_512_depth_64 auth_pipeline_input_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( s_axis_msg_input_fifo.tready ),
    .m_axis_tready ( m_axis_msg_input_fifo.tready ),
    .s_axis_tvalid ( s_axis_msg_input_fifo.tvalid ),
    .s_axis_tdata ( s_axis_msg_input_fifo.tdata ),
    .s_axis_tkeep ( s_axis_msg_input_fifo.tkeep ),
    .s_axis_tlast ( s_axis_msg_input_fifo.tlast ),
    .m_axis_tvalid ( m_axis_msg_input_fifo.tvalid ),
    .m_axis_tdata ( m_axis_msg_input_fifo.tdata ),
    .m_axis_tkeep ( m_axis_msg_input_fifo.tkeep ),
    .m_axis_tlast ( m_axis_msg_input_fifo.tlast )
);

bft_meta_gen_ip auth_meta_gen_inst (
    .s_axis_TREADY ( m_axis_msg_input_fifo.tready ),
    .s_axis_TVALID ( m_axis_msg_input_fifo.tvalid ),
    .s_axis_TDATA ( m_axis_msg_input_fifo.tdata ),
    .s_axis_TKEEP ( m_axis_msg_input_fifo.tkeep ),
    .s_axis_TLAST ( m_axis_msg_input_fifo.tlast ),
    .s_axis_TSTRB (0),
    .m_meta_TVALID (auth_meta_s0.valid),
    .m_meta_TREADY (auth_meta_s0.ready),
    .m_meta_TDATA (auth_meta_s0.data),
    .m_axis_TREADY ( auth_msg_s0.tready ),
    .m_axis_TVALID ( auth_msg_s0.tvalid ),
    .m_axis_TDATA ( auth_msg_s0.tdata ),
    .m_axis_TKEEP ( auth_msg_s0.tkeep ),
    .m_axis_TLAST ( auth_msg_s0.tlast ),
    .ap_clk(aclk),
    .ap_rst_n(aresetn)
);

// payload forward to width converter
// make sure the data is masked by keep signal, this can be done outside the pipe to save logic
// pad the keep signal to all 1 as the hmac module expects 64 B alignment

assign auth_msg_s1.tvalid = auth_msg_s0.tvalid;
assign auth_msg_s1.tdata = auth_msg_s0.tdata;
assign auth_msg_s1.tkeep = {64{1'b1}};
assign auth_msg_s1.tlast = auth_msg_s0.tlast;
assign auth_msg_s0.tready = auth_msg_s1.tready;

axis_dwidth_converter_512_to_32 dwidth_payload_converter_512_to_32 (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( auth_msg_s1.tready ),
    .m_axis_tready ( auth_msg_w32_s0.tready ),
    .s_axis_tvalid ( auth_msg_s1.tvalid ),
    .s_axis_tdata ( auth_msg_s1.tdata ),
    .s_axis_tkeep ( auth_msg_s1.tkeep ),
    .s_axis_tlast ( auth_msg_s1.tlast ),
    .m_axis_tvalid ( auth_msg_w32_s0.tvalid ),
    .m_axis_tdata ( auth_msg_w32_s0.tdata ),
    .m_axis_tkeep ( auth_msg_w32_s0.tkeep ),
    .m_axis_tlast ( auth_msg_w32_s0.tlast )
);



auth_hmac_wrapper #( 
    .PIPE_INDEX(PIPE_INDEX),
    .DEBUG(DEBUG)
)auth_hmac_wrapper (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_config (key_config_w256),
    .s_msg (auth_msg_w32_s0),
    .m_smg (auth_msg_w32_s1),
    .s_meta (auth_meta_s0),
    .m_hsh (auth_hsh)
);

axis_dwidth_converter_32_to_512 dwidth_converter_32_to_512 (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tready ( auth_msg_w32_s1.tready ),
    .m_axis_tready ( auth_msg_s2.tready ),
    .s_axis_tvalid ( auth_msg_w32_s1.tvalid ),
    .s_axis_tdata ( auth_msg_w32_s1.tdata ),
    .s_axis_tkeep ( auth_msg_w32_s1.tkeep ),
    .s_axis_tlast ( auth_msg_w32_s1.tlast ),
    .m_axis_tvalid ( auth_msg_s2.tvalid ),
    .m_axis_tdata ( auth_msg_s2.tdata ),
    .m_axis_tkeep ( auth_msg_s2.tkeep ),
    .m_axis_tlast ( auth_msg_s2.tlast )
);

axis_packet_fifo_width_512_depth_64 auth_pipeline_output_msg_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( auth_msg_s2.tready ),
    .m_axis_tready ( auth_msg_s3.tready ),
    .s_axis_tvalid ( auth_msg_s2.tvalid ),
    .s_axis_tdata ( auth_msg_s2.tdata ),
    .s_axis_tkeep ( auth_msg_s2.tkeep ),
    .s_axis_tlast ( auth_msg_s2.tlast ),
    .m_axis_tvalid ( auth_msg_s3.tvalid ),
    .m_axis_tdata ( auth_msg_s3.tdata ),
    .m_axis_tkeep ( auth_msg_s3.tkeep ),
    .m_axis_tlast ( auth_msg_s3.tlast )
);


auth_pipe_out_handler_ip auth_pipe_out_handler_inst(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .s_meta_hsh_TDATA(auth_hsh.data),
    .s_meta_hsh_TVALID(auth_hsh.valid),
    .s_meta_hsh_TREADY(auth_hsh.ready),
    .s_axis_msg_TDATA(auth_msg_s3.tdata),
    .s_axis_msg_TVALID(auth_msg_s3.tvalid),
    .s_axis_msg_TREADY(auth_msg_s3.tready),
    .s_axis_msg_TKEEP(auth_msg_s3.tkeep),
    .s_axis_msg_TSTRB(0),
    .s_axis_msg_TLAST(auth_msg_s3.tlast),
    .m_axis_msg_TDATA(auth_out_s0.tdata),
    .m_axis_msg_TVALID(auth_out_s0.tvalid),
    .m_axis_msg_TREADY(auth_out_s0.tready),
    .m_axis_msg_TKEEP(auth_out_s0.tkeep),
    .m_axis_msg_TSTRB(),
    .m_axis_msg_TLAST(auth_out_s0.tlast)
);


axis_register_slice_width_512 reg_slice_512 (
    .aclk ( aclk ),
    .aresetn ( aresetn ),
    .s_axis_tkeep ( auth_out_s0.tkeep ),
    .s_axis_tlast ( auth_out_s0.tlast ),
    .s_axis_tready ( auth_out_s0.tready ),
    .s_axis_tvalid ( auth_out_s0.tvalid ),
    .s_axis_tdata ( auth_out_s0.tdata ),
    .m_axis_tkeep ( auth_out.tkeep ),
    .m_axis_tlast ( auth_out.tlast ),
    .m_axis_tready ( auth_out.tready ),
    .m_axis_tvalid ( auth_out.tvalid ),
    .m_axis_tdata ( auth_out.tdata )
);


// auth key init stream pipeline
// tid - 0: auth message stream - 1: auth key init stream
// the actual payload is 256 bit per word

assign axis_key_config_w512.tvalid = m_axis_input_switch_tvalid[1];
assign m_axis_input_switch_tready[1] = axis_key_config_w512.tready;
assign axis_key_config_w512.tlast = m_axis_input_switch_tlast[1];
assign axis_key_config_w512.tdata = m_axis_input_switch_tdata[(1+1)*512-1:1*512];
assign axis_key_config_w512.tkeep = m_axis_input_switch_tkeep[(1+1)*64-1:1*64];

assign key_config_w256.valid = axis_key_config_w512.tvalid;
assign key_config_w256.data = axis_key_config_w512.tdata;
assign axis_key_config_w512.tready = key_config_w256.ready;

`ifdef DEBUG_AUTH_PIPE
    if (PIPE_INDEX == 0) begin
        ila_auth_pipe ila_auth_pipe
        (
            .clk(aclk), // input wire clk
            // msg input
            .probe0(auth_msg_s0.tvalid),  //1
            .probe1(auth_msg_s0.tready), //1
            .probe2(auth_msg_s0.tlast), //1
            .probe3(auth_msg_s0.tdata), // 512
            // internal
            .probe4(auth_hsh.valid), //1
            .probe5(auth_hsh.ready), //1
            .probe6(auth_hsh.valid), //1
            .probe7(auth_hsh.ready), // 1
            // meta
            .probe8(auth_meta_s0.valid), // 1
            .probe9(auth_meta_s0.ready), //1
            .probe10(auth_meta_s0.data), // 64
            // init key
            .probe11(key_config_w256.valid), //1
            .probe12(key_config_w256.ready), //1
            .probe13(key_config_w256.data), //256

            // auth output
            .probe14(auth_out_s0.tdata), //512
            .probe15(auth_out_s0.tvalid), //1
            .probe16(auth_out_s0.tready), //1
            .probe17(auth_out_s0.tlast) // 1
        );
    end
`endif 


endmodule
