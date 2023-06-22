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

/**
 * User logic
 * 
 */
module tcp_intf_wrapper (
    // control
    input wire                  ap_start_pulse,
    input wire [63:0]           maxPkgWord,

    // User Interface
    metaIntf.s                  open_con_cmd,
    metaIntf.s                  open_port_cmd,
    metaIntf.s                  close_con_cmd,
    metaIntf.m                  open_con_sts,
    metaIntf.m                  open_port_sts,
    AXI4S.s                     netTxData,
    metaIntf.s                  netTxMeta,
    AXI4S.m                     netRxData,
    metaIntf.m                  netRxMeta,

    // TCP/IP QSFP0 CMD
    metaIntf.m			        tcp_0_listen_req,
    metaIntf.s			        tcp_0_listen_rsp,
    metaIntf.m			        tcp_0_open_req,
    metaIntf.s			        tcp_0_open_rsp,
    metaIntf.m			        tcp_0_close_req,
    metaIntf.s			        tcp_0_notify,
    metaIntf.m			        tcp_0_rd_pkg,
    metaIntf.s			        tcp_0_rx_meta,
    metaIntf.m			        tcp_0_tx_meta,
    metaIntf.s			        tcp_0_tx_stat,

    // AXI4S TCP/IP QSFP0 STREAMS
    AXI4S.s                     axis_tcp_0_sink,
    AXI4S.m                     axis_tcp_0_src,

    // debug registers
    output wire [63:0]  	    consumed_bytes_network,
    output wire [63:0]  	    produced_bytes_network,
    output wire [63:0]  	    produced_pkt_network,
    output wire [63:0]          consumed_pkt_network,
    output wire [63:0]          net_device_down,
    output wire [63:0]          device_net_down,
    output wire [63:0]          net_tx_cmd_error,

    // Clock and reset
    input  wire                 aclk,
    input  wire[0:0]            aresetn
);

logic [0:0] ap_start_pulse_reg;
logic [63:0] maxPkgWord_reg;

always @(posedge aclk) begin
	ap_start_pulse_reg <= ap_start_pulse;
    maxPkgWord_reg <= maxPkgWord;
end

// TCP interface

wire [7:0]tcp_listen_rsp_TDATA;
wire tcp_listen_rsp_TREADY;
wire tcp_listen_rsp_TVALID;

assign tcp_listen_rsp_TDATA = tcp_0_listen_rsp.data;

assign tcp_listen_rsp_TVALID = tcp_0_listen_rsp.valid;
assign tcp_0_listen_rsp.ready = tcp_listen_rsp_TREADY;

wire [127:0]tcp_notify_TDATA;
wire tcp_notify_TREADY;
wire tcp_notify_TVALID;

assign tcp_notify_TDATA[15:0] = tcp_0_notify.data.sid; //session
assign tcp_notify_TDATA[31:16] = tcp_0_notify.data.len; //length
assign tcp_notify_TDATA[63:32] = tcp_0_notify.data.ip_address; //ip_address
assign tcp_notify_TDATA[79:64] = tcp_0_notify.data.dst_port; //dst_port
assign tcp_notify_TDATA[80:80] = tcp_0_notify.data.closed; //closed
assign tcp_notify_TDATA[127:81] = 0;

assign tcp_notify_TVALID = tcp_0_notify.valid;
assign tcp_0_notify.ready = tcp_notify_TREADY;

wire [127:0]tcp_open_rsp_TDATA;
wire tcp_open_rsp_TREADY;
wire tcp_open_rsp_TVALID;

assign tcp_open_rsp_TDATA[15:0] = tcp_0_open_rsp.data.sid; //session
assign tcp_open_rsp_TDATA[23:16] = tcp_0_open_rsp.data.success;
assign tcp_open_rsp_TDATA[55:24] = tcp_0_open_rsp.data.ip_address;
assign tcp_open_rsp_TDATA[71:56] = tcp_0_open_rsp.data.ip_port;
assign tcp_open_rsp_TDATA[127:72] = 0;

assign tcp_open_rsp_TVALID = tcp_0_open_rsp.valid;
assign tcp_0_open_rsp.ready = tcp_open_rsp_TREADY;

wire [15:0]tcp_rx_meta_TDATA;
wire tcp_rx_meta_TREADY;
wire tcp_rx_meta_TVALID;

assign tcp_rx_meta_TDATA = tcp_0_rx_meta.data;

assign tcp_rx_meta_TVALID = tcp_0_rx_meta.valid;
assign tcp_0_rx_meta.ready = tcp_rx_meta_TREADY;

wire [63:0]tcp_tx_stat_TDATA;
wire tcp_tx_stat_TREADY;
wire tcp_tx_stat_TVALID;

assign tcp_tx_stat_TDATA[15:0] = tcp_0_tx_stat.data.sid;
assign tcp_tx_stat_TDATA[31:16] = tcp_0_tx_stat.data.len;
assign tcp_tx_stat_TDATA[61:32] = tcp_0_tx_stat.data.remaining_space;
assign tcp_tx_stat_TDATA[63:62] = tcp_0_tx_stat.data.error;

assign tcp_tx_stat_TVALID = tcp_0_tx_stat.valid;
assign tcp_0_tx_stat.ready = tcp_tx_stat_TREADY;

wire [31:0]tcp_tx_meta_TDATA;
wire tcp_tx_meta_TREADY;
wire tcp_tx_meta_TVALID;

assign tcp_0_tx_meta.data.sid = tcp_tx_meta_TDATA[15:0];
assign tcp_0_tx_meta.data.len = tcp_tx_meta_TDATA[31:16];

assign tcp_0_tx_meta.valid = tcp_tx_meta_TVALID;
assign tcp_tx_meta_TREADY = tcp_0_tx_meta.ready;

wire [31:0]tcp_rd_package_TDATA;
wire tcp_rd_package_TREADY;
wire tcp_rd_package_TVALID;

assign tcp_0_rd_pkg.data.sid = tcp_rd_package_TDATA[15:0];
assign tcp_0_rd_pkg.data.len = tcp_rd_package_TDATA[31:16];

assign tcp_0_rd_pkg.valid = tcp_rd_package_TVALID;
assign tcp_rd_package_TREADY = tcp_0_rd_pkg.ready;

wire [15:0]tcp_listen_req_TDATA;
wire tcp_listen_req_TREADY;
wire tcp_listen_req_TVALID;

assign tcp_0_listen_req.data = tcp_listen_req_TDATA;

assign tcp_0_listen_req.valid = tcp_listen_req_TVALID;
assign tcp_listen_req_TREADY = tcp_0_listen_req.ready;

wire [63:0]tcp_open_req_TDATA;
wire tcp_open_req_TREADY;
wire tcp_open_req_TVALID;

assign tcp_0_open_req.data.ip_address = tcp_open_req_TDATA[31:0];
assign tcp_0_open_req.data.ip_port = tcp_open_req_TDATA[47:32];

assign tcp_0_open_req.valid = tcp_open_req_TVALID;
assign tcp_open_req_TREADY = tcp_0_open_req.ready;

assign close_con_cmd.ready = 1'b1;

logic [63:0] axis_tcp_0_sink_ready_down, axis_tcp_0_src_ready_down;

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) axis_tcp_0_sink_reg();

axis_reg_array_profiler #(.N_STAGES(4), .DATA_BITS(AXI_DATA_BITS)) 
inst_axis_tcp_0_sink_reg_array 
(
    .aclk(aclk), 
    .aresetn(aresetn), 
    .ap_start_pulse(ap_start_pulse_reg),
    .s_axis(axis_tcp_0_sink), 
    .m_axis(axis_tcp_0_sink_reg), 
    .byte_cnt(consumed_bytes_network), 
    .pkt_cnt(consumed_pkt_network), 
    .ready_down(axis_tcp_0_sink_ready_down)
);

assign net_device_down = axis_tcp_0_sink_ready_down;

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) axis_tcp_0_src_reg();

axis_reg_array_profiler #(.N_STAGES(4), .DATA_BITS(AXI_DATA_BITS)) 
inst_axis_tcp_0_src_reg_array 
(
    .aclk(aclk), 
    .aresetn(aresetn), 
    .ap_start_pulse(ap_start_pulse_reg),
    .s_axis(axis_tcp_0_src_reg), 
    .m_axis(axis_tcp_0_src), 
    .byte_cnt(produced_bytes_network), 
    .pkt_cnt(produced_pkt_network), 
    .ready_down(axis_tcp_0_src_ready_down)
);

assign device_net_down = axis_tcp_0_src_ready_down;

tcp_intf_ip tcp_intf
   (
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .axis_tcp_sink_tdata(axis_tcp_0_sink_reg.tdata),
    .axis_tcp_sink_tkeep(axis_tcp_0_sink_reg.tkeep),
    .axis_tcp_sink_tlast(axis_tcp_0_sink_reg.tlast),
    .axis_tcp_sink_tready(axis_tcp_0_sink_reg.tready),
    .axis_tcp_sink_tstrb(0),
    .axis_tcp_sink_tvalid(axis_tcp_0_sink_reg.tvalid),
    .axis_tcp_src_tdata(axis_tcp_0_src_reg.tdata),
    .axis_tcp_src_tkeep(axis_tcp_0_src_reg.tkeep),
    .axis_tcp_src_tlast(axis_tcp_0_src_reg.tlast),
    .axis_tcp_src_tready(axis_tcp_0_src_reg.tready),
    .axis_tcp_src_tstrb(),
    .axis_tcp_src_tvalid(axis_tcp_0_src_reg.tvalid),
    .open_con_cmd_tdata(open_con_cmd.data),
    .open_con_cmd_tready(open_con_cmd.ready),
    .open_con_cmd_tvalid(open_con_cmd.valid),
    .open_con_sts_tdata(open_con_sts.data),
    .open_con_sts_tready(open_con_sts.ready),
    .open_con_sts_tvalid(open_con_sts.valid),
    .open_port_cmd_tdata(open_port_cmd.data),
    .open_port_cmd_tready(open_port_cmd.ready),
    .open_port_cmd_tvalid(open_port_cmd.valid),
    .open_port_sts_tdata(open_port_sts.data),
    .open_port_sts_tready(open_port_sts.ready),
    .open_port_sts_tvalid(open_port_sts.valid),
    .rx_data_tdata(netRxData.tdata),
    .rx_data_tkeep(netRxData.tkeep),
    .rx_data_tlast(netRxData.tlast),
    .rx_data_tready(netRxData.tready),
    .rx_data_tstrb(),
    .rx_data_tvalid(netRxData.tvalid),
    .rx_meta_tdata(netRxMeta.data),
    .rx_meta_tready(netRxMeta.ready),
    .rx_meta_tvalid(netRxMeta.valid),
    .tcp_listen_req_tdata(tcp_listen_req_TDATA),
    .tcp_listen_req_tready(tcp_listen_req_TREADY),
    .tcp_listen_req_tvalid(tcp_listen_req_TVALID),
    .tcp_listen_rsp_tdata(tcp_listen_rsp_TDATA),
    .tcp_listen_rsp_tready(tcp_listen_rsp_TREADY),
    .tcp_listen_rsp_tvalid(tcp_listen_rsp_TVALID),
    .tcp_notify_tdata(tcp_notify_TDATA),
    .tcp_notify_tready(tcp_notify_TREADY),
    .tcp_notify_tvalid(tcp_notify_TVALID),
    .tcp_open_req_tdata(tcp_open_req_TDATA),
    .tcp_open_req_tready(tcp_open_req_TREADY),
    .tcp_open_req_tvalid(tcp_open_req_TVALID),
    .tcp_open_rsp_tdata(tcp_open_rsp_TDATA),
    .tcp_open_rsp_tready(tcp_open_rsp_TREADY),
    .tcp_open_rsp_tvalid(tcp_open_rsp_TVALID),
    .tcp_rd_package_tdata(tcp_rd_package_TDATA),
    .tcp_rd_package_tready(tcp_rd_package_TREADY),
    .tcp_rd_package_tvalid(tcp_rd_package_TVALID),
    .tcp_rx_meta_tdata(tcp_rx_meta_TDATA),
    .tcp_rx_meta_tready(tcp_rx_meta_TREADY),
    .tcp_rx_meta_tvalid(tcp_rx_meta_TVALID),
    .tx_meta_tdata(netTxMeta.data),
    .tx_meta_tready(netTxMeta.ready),
    .tx_meta_tvalid(netTxMeta.valid),
    .tcp_tx_meta_tdata(tcp_tx_meta_TDATA),
    .tcp_tx_meta_tready(tcp_tx_meta_TREADY),
    .tcp_tx_meta_tvalid(tcp_tx_meta_TVALID),
    .tcp_tx_stat_tdata(tcp_tx_stat_TDATA),
    .tcp_tx_stat_tready(tcp_tx_stat_TREADY),
    .tcp_tx_stat_tvalid(tcp_tx_stat_TVALID),
    .tx_data_tdata(netTxData.tdata),
    .tx_data_tkeep(netTxData.tkeep),
    .tx_data_tlast(netTxData.tlast),
    .tx_data_tready(netTxData.tready),
    .tx_data_tstrb(0),
    .tx_data_tvalid(netTxData.tvalid),
    .maxPkgWord (maxPkgWord_reg)
    );

logic [63:0] tx_status_error_cnt;
logic [63:0] execution_cycles;

always @( posedge aclk ) begin 
	if (~aresetn) begin
		tx_status_error_cnt <= '0;
        execution_cycles <= '0;
	end
	else begin
		if (ap_start_pulse) begin
			tx_status_error_cnt <= '0;
            execution_cycles <= '0;
		end
		else begin
            execution_cycles <= execution_cycles + 1'b1;

            if (tcp_0_tx_stat.valid & tcp_0_tx_stat.ready & tcp_0_tx_stat.data.error != 0) begin
                tx_status_error_cnt <= tx_status_error_cnt + 1'b1;
            end

		end
	end
end

assign net_tx_cmd_error = tx_status_error_cnt;

`define ILA_TCP_DEBUG
`ifdef ILA_TCP_DEBUG
ila_tcp tcp_debug (
  .clk(aclk), // input wire clk

  .probe0(tcp_0_open_req.valid), // 1  
  .probe1(tcp_0_open_req.ready), // 1  
  .probe2(tcp_0_open_req.data.ip_address), // 32    
  .probe3(tcp_0_open_req.data.ip_port), // 16 
  .probe4(tcp_0_open_rsp.valid), // 1   
  .probe5(tcp_0_open_rsp.ready), // 1                      
  .probe6(tcp_0_open_rsp.data.sid), // 16                      
  .probe7(tcp_0_open_rsp.data.success), // 1                        
  .probe8(tcp_0_listen_req.valid),    //1                                                
  .probe9(tcp_0_listen_req.ready),//1
  .probe10(tcp_0_listen_req.data[15:0]),//16
  .probe11(tcp_0_listen_rsp.valid),//1
  .probe12(tcp_0_listen_rsp.ready),//1
  .probe13(tcp_0_listen_rsp.data[0]), //1
  .probe14(tcp_0_tx_stat.valid), //1    
  .probe15(tcp_0_tx_stat.ready), //1
  .probe16(tcp_0_tx_stat.data[63:0]), // 64
  .probe17(tcp_0_tx_meta.valid), // 1
  .probe18(tcp_0_tx_meta.ready),// 1 
  .probe19(tcp_0_tx_meta.data[31:0]), // 32  
  .probe20(axis_tcp_0_src.tvalid), // 1
  .probe21(axis_tcp_0_src.tready), // 1
  .probe22(axis_tcp_0_src.tlast), //1
  .probe23(tcp_0_notify.valid), //1
  .probe24(tcp_0_notify.ready), //1
  .probe25(tcp_0_notify.data.sid), //16
  .probe26(tcp_0_notify.data.len), //16
  .probe27(tcp_0_rx_meta.valid), //1
  .probe28(tcp_0_rx_meta.ready),//1
  .probe29(tcp_0_rx_meta.data), //16
  .probe30(tcp_0_rd_pkg.valid), //1
  .probe31(tcp_0_rd_pkg.ready),  // 1
  .probe32(tcp_0_rd_pkg.data),  // 32
  .probe33(axis_tcp_0_sink.tvalid),   // 1
  .probe34(axis_tcp_0_sink.tready),   //1
  .probe35(axis_tcp_0_sink.tlast),    // 1
  .probe36(open_con_sts.valid),                // 1
  .probe37(open_con_sts.ready),              // 1
  .probe38(open_con_sts.data),               //128
  .probe39(open_port_sts.valid), //1
  .probe40(open_port_sts.ready), //1
  .probe41(open_port_sts.data), //32
  .probe42(execution_cycles), //32
  .probe43(consumed_bytes_network), //32
  .probe44(produced_bytes_network) //32
);
`endif 

endmodule