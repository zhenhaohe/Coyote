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

`include "axi_macros.svh"
`include "lynx_macros.svh"

import lynxTypes::*;
import bftTypes::*;

/**
 * User logic
 * 
 */
module host_wrapper (
    // DESCRIPTOR BYPASS
    metaIntf.m			            bpss_rd_req,
    metaIntf.m			            bpss_wr_req,
    metaIntf.s                      bpss_rd_done,
    metaIntf.s                      bpss_wr_done,

    // AXI4S HOST STREAMS
    AXI4SR.s                        axis_host_0_sink,
    AXI4SR.m                        axis_host_0_src,

    //CCL interface
    AXI4S.s                         device2host,
    metaIntf.s                      device2host_meta,

    AXI4SR.m                        host2device,

    // Runtime Parameter
	input wire [0:0]				ap_clr_pulse,
	input wire [63:0]				batchMaxTimer,

	metaIntf.s 						buff_cmd,

    // debug registers
    output wire [63:0]  	        consumed_bytes_host,
    output wire [63:0]  	        produced_bytes_host,
    output wire [63:0]  	        produced_pkt_host,
    output wire [63:0]              consumed_pkt_host,
	output wire [63:0] 				host_device_down,
	output wire [63:0]				device_host_down,

    // Clock and reset
    input  wire                     aclk,
    input  wire[0:0]                aresetn
);

logic [0:0]     ap_clr_pulse_reg;
logic [63:0] 	batchMaxTimer_reg;

always @(posedge aclk) begin
	ap_clr_pulse_reg <= ap_clr_pulse;
	batchMaxTimer_reg <= batchMaxTimer;
end

//-------------------- Host - Device--------------------------// 
always_comb bpss_rd_req.tie_off_m();
always_comb bpss_rd_done.tie_off_s();

logic [63:0] axis_host_0_sink_ready_down;

axisr_reg_array_profiler #(.N_STAGES(3), .DATA_BITS(AXI_DATA_BITS))  
inst_axis_host_0_sink_reg_array 
(
    .aclk(aclk), 
    .aresetn(aresetn), 
    .reset(ap_clr_pulse_reg),
    .s_axis(axis_host_0_sink), 
    .m_axis(host2device), 
    .byte_cnt(consumed_bytes_host), 
    .pkt_cnt(consumed_pkt_host), 
    .ready_down(axis_host_0_sink_ready_down)
);

assign host_device_down = axis_host_0_sink_ready_down;
//-------------------- Device - Host--------------------------// 

logic [63:0] axis_host_0_src_ready_down;

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) device2host_reg();
metaIntf #(.STYPE(logic [63:0])) device2host_meta_reg();

axis_reg_array #(.N_STAGES(3)) inst_device2host_reg_array (.aclk(aclk), .aresetn(aresetn), .s_axis(device2host), .m_axis(device2host_reg));
meta_reg_array  #(.N_STAGES(3), .DATA_BITS(64)) inst_device2host_meta_reg_array (.aclk(aclk), .aresetn(aresetn), .s_meta(device2host_meta), .m_meta(device2host_meta_reg));


AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) batcherDataIn();
metaIntf #(.STYPE(logic [63:0])) batcherMetaIn();

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) batcherDataOut();
metaIntf #(.STYPE(logic [63:0])) batcherMetaOut();

// very small meta fifo
axis_meta_fifo_width_64_depth_16 meta_in_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( device2host_meta_reg.ready ),
    .m_axis_tready ( batcherMetaIn.ready ),
    .s_axis_tvalid ( device2host_meta_reg.valid ),
    .s_axis_tdata ( device2host_meta_reg.data ),
    .m_axis_tvalid ( batcherMetaIn.valid ),
    .m_axis_tdata ( batcherMetaIn.data )
);

// 8KB fifo to buffer input
axis_data_fifo_width_512_depth_128 tx_data_in_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( device2host_reg.tready ),
    .m_axis_tready ( batcherDataIn.tready ),
    .s_axis_tvalid ( device2host_reg.tvalid ),
    .s_axis_tdata ( device2host_reg.tdata ),
    .s_axis_tkeep ( device2host_reg.tkeep ),
    .s_axis_tlast ( device2host_reg.tlast ),
    .m_axis_tvalid ( batcherDataIn.tvalid ),
    .m_axis_tdata ( batcherDataIn.tdata ),
    .m_axis_tkeep ( batcherDataIn.tkeep ),
    .m_axis_tlast ( batcherDataIn.tlast )
);

host_packetBatcher_ip host_packetBatcher (
	.netTxCmd_in_TDATA(batcherMetaIn.data),
	.netTxData_in_TDATA(batcherDataIn.tdata),
	.netTxData_in_TKEEP(batcherDataIn.tkeep),
	.netTxData_in_TSTRB(0),
	.netTxData_in_TLAST(batcherDataIn.tlast),
	.netTxCmd_out_TDATA(batcherMetaOut.data),
	.netTxData_out_TDATA(batcherDataOut.tdata),
	.netTxData_out_TKEEP(batcherDataOut.tkeep),
	.netTxData_out_TSTRB(0),
	.netTxData_out_TLAST(batcherDataOut.tlast),
	.batchMaxTimer(batchMaxTimer_reg),
	.ap_clk(aclk),
	.ap_rst_n(aresetn),
	.netTxCmd_in_TVALID(batcherMetaIn.valid),
	.netTxCmd_in_TREADY(batcherMetaIn.ready),
	.netTxCmd_out_TVALID(batcherMetaOut.valid),
	.netTxCmd_out_TREADY(batcherMetaOut.ready),
	.netTxData_in_TVALID(batcherDataIn.tvalid),
	.netTxData_in_TREADY(batcherDataIn.tready),
	.netTxData_out_TVALID(batcherDataOut.tvalid),
	.netTxData_out_TREADY(batcherDataOut.tready)
);

// manage write process
metaIntf #(.STYPE(logic [127:0])) host_wr_req();
metaIntf #(.STYPE(logic [127:0])) host_wr_req_reg();
AXI4SR #(.AXI4S_DATA_BITS(AXI_DATA_BITS),.AXI4S_ID_BITS(PID_BITS)) host_intf_wr();

metaIntf #(.STYPE(logic [63:0])) buff_cmd_q();

// very small meta fifo
axis_meta_fifo_width_64_depth_16 buff_cmd_in_fifo (
    .s_axis_aclk ( aclk ),
    .s_axis_aresetn ( aresetn ),
    .s_axis_tready ( buff_cmd.ready ),
    .m_axis_tready ( buff_cmd_q.ready ),
    .s_axis_tvalid ( buff_cmd.valid ),
    .s_axis_tdata ( buff_cmd.data ),
    .m_axis_tvalid ( buff_cmd_q.valid ),
    .m_axis_tdata ( buff_cmd_q.data )
);

host_wr_handler_ip host_wr_handler_inst(
	.ap_clk(aclk),
	.ap_rst_n(aresetn),
	.host_wr_data_out_TDATA(host_intf_wr.tdata),
	.host_wr_data_out_TVALID(host_intf_wr.tvalid),
	.host_wr_data_out_TREADY(host_intf_wr.tready),
	.host_wr_data_out_TKEEP(host_intf_wr.tkeep),
	.host_wr_data_out_TSTRB(),
	.host_wr_data_out_TLAST(host_intf_wr.tlast),
	.host_wr_req_out_TDATA(host_wr_req.data),
	.host_wr_req_out_TVALID(host_wr_req.valid),
	.host_wr_req_out_TREADY(host_wr_req.ready),
	.wr_data_TDATA(batcherDataOut.tdata),
	.wr_data_TVALID(batcherDataOut.tvalid),
	.wr_data_TREADY(batcherDataOut.tready),
	.wr_data_TKEEP(batcherDataOut.tkeep),
	.wr_data_TSTRB(0),
	.wr_data_TLAST(batcherDataOut.tlast),
	.wr_meta_TDATA(batcherMetaOut.data),
	.wr_meta_TVALID(batcherMetaOut.valid),
	.wr_meta_TREADY(batcherMetaOut.ready),
	.buff_cmd_TDATA(buff_cmd_q.data),
	.buff_cmd_TVALID(buff_cmd_q.valid),
	.buff_cmd_TREADY(buff_cmd_q.ready),
  	.ap_clr_pulse(ap_clr_pulse_reg)
);

req_t req;

assign bpss_wr_req.valid = host_wr_req_reg.valid;
assign host_wr_req_reg.ready = bpss_wr_req.ready;
assign bpss_wr_req.data = req;

assign req.vaddr = host_wr_req_reg.data[47:0];
assign req.len = host_wr_req_reg.data[75:48];
assign req.stream = host_wr_req_reg.data[76:76];
assign req.sync = host_wr_req_reg.data[77:77];
assign req.ctl = host_wr_req_reg.data[78:78];
assign req.host = host_wr_req_reg.data[79:79];
assign req.dest = host_wr_req_reg.data[83:80];
assign req.pid = host_wr_req_reg.data[89:84];
assign req.vfid = 0;
assign req.rsrvd = 0;

meta_reg_array  #(.N_STAGES(3), .DATA_BITS(128)) inst_host_wr_req_reg_array (.aclk(aclk), .aresetn(aresetn), .s_meta(host_wr_req), .m_meta(host_wr_req_reg));
axisr_reg_array_profiler #(.N_STAGES(3), .DATA_BITS(AXI_DATA_BITS)) 
inst_axis_host_0_src_reg_array 
(
    .aclk(aclk), 
    .aresetn(aresetn), 
    .reset(ap_clr_pulse_reg),
    .s_axis(host_intf_wr), 
    .m_axis(axis_host_0_src),
    .byte_cnt(produced_bytes_host), 
    .pkt_cnt(produced_pkt_host), 
    .ready_down(axis_host_0_src_ready_down)
);

assign device_host_down = axis_host_0_src_ready_down;

`ifdef ILA_HOST_DEBUG
ila_host host_debug (
	.clk(aclk), // input wire clk

	.probe0(bpss_wr_req.valid), // 1  
	.probe1(bpss_wr_req.ready), // 1  
	.probe2(req.vaddr), // 48    
	.probe3(req.len), // 28
	.probe4(req.stream), // 1   
	.probe5(req.sync), // 1                      
	.probe6(req.ctl), // 1                      
	.probe7(req.host), // 1                        
	.probe8(req.dest), //4                                                
	.probe9(req.pid),//6
	.probe10(req.vfid),//1
	.probe11(buff_cmd.data),//64
	.probe12(batchMaxTimer_reg), //64
	.probe13(bpss_wr_done.valid), //1
	.probe14(buff_cmd.valid), //1
	.probe15(device2host_meta_reg.valid),
	.probe16(device2host_meta_reg.ready),
	.probe17(device2host_reg.tvalid),
	.probe18(device2host_reg.tready)
);
`endif 

endmodule