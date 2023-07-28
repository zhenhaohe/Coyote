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
 
import lynxTypes::*;
import bftTypes::*;

/**
 *  PT Config Slave
 */ 
module bft_coyote_bench_slave (
	input  logic                                  aclk,
	input  logic                                  aresetn,
	
	AXI4L.s                                       axi_ctrl,

	output logic 									                ap_clr,
  output logic 									                ap_start,
  input logic 									                ap_done,

  metaIntf.m                                    buff_cmd, // [47:0] base address offset, [63:48] size in KB
	metaIntf.m                                    comm_meta,

  input bft_tx_stat_t                           bft_tx_stat,
  input bft_rx_stat_t                           bft_rx_stat,

  output logic [63:0]									          exp_tx_net_pkt,
	output logic [63:0]								            exp_rx_net_pkt,
  input logic [63:0]								            execution_cycles,

  input logic [63:0]                            consumed_bytes_network,
	input logic [63:0]                            produced_bytes_network,
	input logic [63:0]                            consumed_bytes_host,
	input logic [63:0]                            produced_bytes_host,
	input logic [63:0]                            consumed_pkt_network,
	input logic [63:0]                            produced_pkt_network,
	input logic [63:0]                            consumed_pkt_host,
	input logic [63:0]                            produced_pkt_host,
  input logic [63:0]                            device_net_down,
  input logic [63:0]                            net_device_down,
  input logic [63:0]                            host_device_down,
  input logic [63:0]                            device_host_down,
  input logic [63:0] 							              net_tx_cmd_error,

  output logic [63:0]                           maxPkgWord,
  output logic [63:0]                           batchMaxTimer
);

//`define  DEBUG_CNFG_SLAVE

// -- Decl ----------------------------------------------------------
// ------------------------------------------------------------------

// AXIL_DATA_BITS = 64
// Constants
localparam integer N_REGS = 64;
localparam integer ADDR_LSB = $clog2(AXIL_DATA_BITS/8);
localparam integer ADDR_MSB = $clog2(N_REGS);
localparam integer AXI_ADDR_BITS = ADDR_LSB + ADDR_MSB;

// Internal registers
logic [AXI_ADDR_BITS-1:0] axi_awaddr;
logic axi_awready;
logic [AXI_ADDR_BITS-1:0] axi_araddr;
logic axi_arready;
logic [1:0] axi_bresp;
logic axi_bvalid;
logic axi_wready;
logic [AXIL_DATA_BITS-1:0] axi_rdata;
logic [1:0] axi_rresp;
logic axi_rvalid;

// Registers
logic [N_REGS-1:0][AXIL_DATA_BITS-1:0] slv_reg;
logic slv_reg_rden;
logic slv_reg_wren;
logic [AXIL_DATA_BITS-1:0] slv_data_out;
logic aw_en;

// -- Def -----------------------------------------------------------
// ------------------------------------------------------------------

/* -- Register map --------------------------------------------------
*/
localparam integer START = 0;
localparam integer STATUS = 1;
localparam integer CLEAR = 2;
localparam integer CONSUMED_BYTES_NETWORK = 7;
localparam integer PRODUCED_BYTES_NETWORK = 8;
localparam integer MAX_PKG_WORD = 11;
localparam integer CONSUMED_BYTES_HOST = 12;
localparam integer PRODUCED_BYTES_HOST = 13;
localparam integer CONSUMED_PKT_NETWORK = 16;
localparam integer PRODUCED_PKT_NETWORK = 17;
localparam integer CONSUMED_PKT_HOST = 18;
localparam integer PRODUCED_PKT_HOST = 19;
localparam integer BATCH_MAX_TIMER = 25;
localparam integer DEVICE_NET_DOWN = 26;
localparam integer NET_DEVICE_DOWN = 27;
localparam integer HOST_DEVICE_DOWN = 28;
localparam integer DEVICE_HOST_DOWN = 29;
localparam integer NET_TX_CMD_ERROR = 30;
localparam integer BUFF_CMD = 31;

localparam integer TX_NET_OFFLOAD_BYTES = 32;
localparam integer TX_NET_OFFLOAD_PKT = 33;
localparam integer TX_NET_OFFLOAD_DOWN = 34;
localparam integer TX_AUTH_OFFLOAD_BYTES = 35;
localparam integer TX_AUTH_OFFLOAD_PKT = 36;
localparam integer TX_AUTH_OFFLOAD_DOWN = 37;
localparam integer RX_NET_OFFLOAD_BYTES = 38;
localparam integer RX_NET_OFFLOAD_PKT = 39;
localparam integer RX_NET_OFFLOAD_DOWN = 40;
localparam integer RX_AUTH_OFFLOAD_BYTES = 41;
localparam integer RX_AUTH_OFFLOAD_PKT = 42;
localparam integer RX_AUTH_OFFLOAD_DOWN = 43;
localparam integer EXECUTION_CYCLES = 44;
localparam integer EXP_TX_NET_PKT = 45;
localparam integer EXP_RX_NET_PKT = 46;
localparam integer COMMUNICATOR = 47;


// Write process
assign slv_reg_wren = axi_wready && axi_ctrl.wvalid && axi_awready && axi_ctrl.awvalid;

always_ff @(posedge aclk, negedge aresetn) begin
  if ( aresetn == 1'b0 ) begin
    for (int i = 0; i < N_REGS; i++) begin
      slv_reg[i] <= 0;
    end 
    buff_cmd.valid <= 1'b0;
    comm_meta.valid <= 1'b0;
  end
  else begin
    slv_reg[START][0] <= 0;
    slv_reg[CLEAR][0] <= 0;
    buff_cmd.valid <= 1'b0;
    comm_meta.valid <= 1'b0;

    if(slv_reg_wren) begin
      case (axi_awaddr[ADDR_LSB+ADDR_MSB-1:ADDR_LSB])
        START : begin // START
          for (int i = 0; i < 1; i++) begin
            if(axi_ctrl.wstrb[i]) begin
              slv_reg[START][(i*8)+:8] <= axi_ctrl.wdata[(i*8)+:8];
            end
          end
        end  
        MAX_PKG_WORD : begin // maxPkgWord
          for (int i = 0; i < AXIL_DATA_BITS/8; i++) begin
            if(axi_ctrl.wstrb[i]) begin
              slv_reg[MAX_PKG_WORD][(i*8)+:8] <= axi_ctrl.wdata[(i*8)+:8];
            end
          end
        end
        BATCH_MAX_TIMER : begin // batchMaxTimer
          for (int i = 0; i < AXIL_DATA_BITS/8; i++) begin
            if(axi_ctrl.wstrb[i]) begin
              slv_reg[BATCH_MAX_TIMER][(i*8)+:8] <= axi_ctrl.wdata[(i*8)+:8];
            end
          end
        end
        BUFF_CMD : begin // buff_cmd
          for (int i = 0; i < AXIL_DATA_BITS/8; i++) begin
            if(axi_ctrl.wstrb[i]) begin
              slv_reg[BUFF_CMD][(i*8)+:8] <= axi_ctrl.wdata[(i*8)+:8];
            end
          end
          if (axi_ctrl.wstrb != 0) begin
            buff_cmd.valid <= 1'b1;
          end
        end
        CLEAR : begin // CLEAR
          for (int i = 0; i < 1; i++) begin
            if(axi_ctrl.wstrb[i]) begin
              slv_reg[CLEAR][(i*8)+:8] <= axi_ctrl.wdata[(i*8)+:8];
            end
          end
        end  
        EXP_TX_NET_PKT : begin // exp_tx_net_pkt
          for (int i = 0; i < AXIL_DATA_BITS/8; i++) begin
            if(axi_ctrl.wstrb[i]) begin
              slv_reg[EXP_TX_NET_PKT][(i*8)+:8] <= axi_ctrl.wdata[(i*8)+:8];
            end
          end
        end
        EXP_RX_NET_PKT : begin // exp_rx_net_pkt
          for (int i = 0; i < AXIL_DATA_BITS/8; i++) begin
            if(axi_ctrl.wstrb[i]) begin
              slv_reg[EXP_RX_NET_PKT][(i*8)+:8] <= axi_ctrl.wdata[(i*8)+:8];
            end
          end
        end
        COMMUNICATOR : begin // communicator
          for (int i = 0; i < AXIL_DATA_BITS/8; i++) begin
            if(axi_ctrl.wstrb[i]) begin
              slv_reg[COMMUNICATOR][(i*8)+:8] <= axi_ctrl.wdata[(i*8)+:8];
            end
          end
          if (axi_ctrl.wstrb != 0) begin
            comm_meta.valid <= 1'b1;
          end
        end
        default : ;
      endcase
    end
  end
end    

// Output
always_comb begin
  ap_start = slv_reg[START][0];
  maxPkgWord = slv_reg[MAX_PKG_WORD];
  batchMaxTimer = slv_reg[BATCH_MAX_TIMER];
  buff_cmd.data = slv_reg[BUFF_CMD];
  ap_clr = slv_reg[CLEAR][0];
  exp_tx_net_pkt = slv_reg[EXP_TX_NET_PKT];
  exp_rx_net_pkt = slv_reg[EXP_RX_NET_PKT];
  comm_meta.data = slv_reg[COMMUNICATOR];
end

// Read process
assign slv_reg_rden = axi_arready & axi_ctrl.arvalid & ~axi_rvalid;

always_ff @(posedge aclk, negedge aresetn) begin
  if( aresetn == 1'b0 ) begin
    axi_rdata <= 0;
  end
  else begin

    if(slv_reg_rden) begin
      axi_rdata <= 0;
      case (axi_araddr[ADDR_LSB+ADDR_MSB-1:ADDR_LSB])
        CONSUMED_BYTES_NETWORK : begin // consumed_bytes_network
          axi_rdata <= consumed_bytes_network;
        end
        PRODUCED_BYTES_NETWORK : begin // produced_bytes_network
          axi_rdata <= produced_bytes_network;
        end
        MAX_PKG_WORD : begin // maxPkgWord
          axi_rdata <= maxPkgWord;
        end
        CONSUMED_BYTES_HOST : begin // consumed_bytes_host
          axi_rdata <= consumed_bytes_host;
        end
        PRODUCED_BYTES_HOST : begin // produced_bytes_host
          axi_rdata <= produced_bytes_host;
        end
        CONSUMED_PKT_NETWORK : begin // consumed_pkt_network
          axi_rdata <= consumed_pkt_network;
        end
        PRODUCED_PKT_NETWORK : begin // produced_pkt_network
          axi_rdata <= produced_pkt_network;
        end
        CONSUMED_PKT_HOST : begin // consumed_pkt_host
          axi_rdata <= consumed_pkt_host;
        end
        PRODUCED_PKT_HOST : begin // produced_pkt_host
          axi_rdata <= produced_pkt_host;
        end
        BATCH_MAX_TIMER : begin // batchMaxTimer
          axi_rdata <= batchMaxTimer;
        end
        DEVICE_NET_DOWN : begin // device_net_down
          axi_rdata <= device_net_down;
        end
        NET_DEVICE_DOWN : begin // net_device_down
          axi_rdata <= net_device_down;
        end
        HOST_DEVICE_DOWN : begin // host_device_down
          axi_rdata <= host_device_down;
        end
        DEVICE_HOST_DOWN : begin // device_host_down
          axi_rdata <= device_host_down;
        end
        NET_TX_CMD_ERROR : begin // net_tx_cmd_error
          axi_rdata <= net_tx_cmd_error;
        end
        STATUS : begin // ap_done
          axi_rdata <= ap_done;
        end
        TX_NET_OFFLOAD_BYTES : begin // tx_net_offload_bytes
          axi_rdata <= bft_tx_stat.net_offload_bytes;
        end
        TX_NET_OFFLOAD_PKT : begin // tx_net_offload_pkt
          axi_rdata <= bft_tx_stat.net_offload_pkt;
        end
        TX_NET_OFFLOAD_DOWN : begin // tx_net_offload_down
          axi_rdata <= bft_tx_stat.net_offload_down;
        end
        TX_AUTH_OFFLOAD_BYTES : begin // tx_auth_offload_bytes
          axi_rdata <= bft_tx_stat.auth_offload_bytes;
        end
        TX_AUTH_OFFLOAD_PKT : begin // tx_auth_offload_pkt
          axi_rdata <= bft_tx_stat.auth_offload_pkt;
        end
        TX_AUTH_OFFLOAD_DOWN : begin // tx_auth_offload_down
          axi_rdata <= bft_tx_stat.auth_offload_down;
        end
        RX_NET_OFFLOAD_BYTES : begin // rx_net_offload_bytes
          axi_rdata <= bft_rx_stat.net_offload_bytes;
        end
        RX_NET_OFFLOAD_PKT : begin // rx_net_offload_pkt
          axi_rdata <= bft_rx_stat.net_offload_pkt;
        end
        RX_NET_OFFLOAD_DOWN : begin // rx_net_offload_down
          axi_rdata <= bft_rx_stat.net_offload_down;
        end
        RX_AUTH_OFFLOAD_BYTES : begin // rx_auth_offload_bytes
          axi_rdata <= bft_rx_stat.auth_offload_bytes;
        end
        RX_AUTH_OFFLOAD_PKT : begin // rx_auth_offload_pkt
          axi_rdata <= bft_rx_stat.auth_offload_pkt;
        end
        RX_AUTH_OFFLOAD_DOWN : begin // rx_auth_offload_down
          axi_rdata <= bft_rx_stat.auth_offload_down;
        end
        EXECUTION_CYCLES : begin // execution_cycles
          axi_rdata <= execution_cycles;
        end
        EXP_RX_NET_PKT : begin // exp_rx_net_pkt
          axi_rdata <= exp_rx_net_pkt;
        end
        EXP_TX_NET_PKT : begin // exp_tx_net_pkt
          axi_rdata <= exp_tx_net_pkt;
        end
      endcase
    end
  end 
end


`ifdef DEBUG_CNFG_SLAVE
ila_cnfg_slave ila_cnfg_slave
(
 .clk(aclk), // input wire clk
  .probe0(slv_reg_rden), //1
  .probe1(axi_rdata), // 64
  .probe2(axi_rvalid), // 1
  .probe3(axi_arready), // 1
  .probe4(axi_ctrl.rready), //1
  .probe5(axi_ctrl.arvalid), //1
  .probe6(axi_ctrl.araddr), //64
  .probe7(axi_bvalid), //1
  .probe8(slv_reg_wren),  //1
  .probe9(axi_ctrl.wdata[63:0]), //64
  .probe10(axi_ctrl.awready), //1
  .probe11(axi_ctrl.awvalid), //1
  .probe12(axi_ctrl.awaddr), //64
  .probe13(buff_cmd.valid), //1
  .probe14(buff_cmd.ready), //1
  .probe15(buff_cmd.data), //64
  .probe16(comm_meta.valid), //1
  .probe17(comm_meta.ready), //1
  .probe18(comm_meta.data), //64
  .probe19(ap_clr), //1
  .probe20(ap_start), //1
  .probe21(ap_done), //1
  .probe22(exp_tx_net_pkt), //64
  .probe23(exp_rx_net_pkt), //64
  .probe24(batchMaxTimer), //64
  .probe25(axi_ctrl.wstrb) //8
 ); 
`endif

// I/O
assign axi_ctrl.awready = axi_awready;
assign axi_ctrl.arready = axi_arready;
assign axi_ctrl.bresp = axi_bresp;
assign axi_ctrl.bvalid = axi_bvalid;
assign axi_ctrl.wready = axi_wready;
assign axi_ctrl.rdata = axi_rdata;
assign axi_ctrl.rresp = axi_rresp;
assign axi_ctrl.rvalid = axi_rvalid;

// awready and awaddr
always_ff @(posedge aclk, negedge aresetn) begin
  if ( aresetn == 1'b0 )
    begin
      axi_awready <= 1'b0;
      axi_awaddr <= 0;
      aw_en <= 1'b1;
    end 
  else
    begin    
      if (~axi_awready && axi_ctrl.awvalid && axi_ctrl.wvalid && aw_en)
        begin
          axi_awready <= 1'b1;
          aw_en <= 1'b0;
          axi_awaddr <= axi_ctrl.awaddr;
        end
      else if (axi_ctrl.bready && axi_bvalid)
        begin
          aw_en <= 1'b1;
          axi_awready <= 1'b0;
        end
      else           
        begin
          axi_awready <= 1'b0;
        end
    end 
end  

// arready and araddr
always_ff @(posedge aclk, negedge aresetn) begin
  if ( aresetn == 1'b0 )
    begin
      axi_arready <= 1'b0;
      axi_araddr  <= 0;
    end 
  else
    begin    
      if (~axi_arready && axi_ctrl.arvalid)
        begin
          axi_arready <= 1'b1;
          axi_araddr  <= axi_ctrl.araddr;
        end
      else
        begin
          axi_arready <= 1'b0;
        end
    end 
end    

// bvalid and bresp
always_ff @(posedge aclk, negedge aresetn) begin
  if ( aresetn == 1'b0 )
    begin
      axi_bvalid  <= 0;
      axi_bresp   <= 2'b0;
    end 
  else
    begin    
      if (axi_awready && axi_ctrl.awvalid && ~axi_bvalid && axi_wready && axi_ctrl.wvalid)
        begin
          axi_bvalid <= 1'b1;
          axi_bresp  <= 2'b0;
        end                   
      else
        begin
          if (axi_ctrl.bready && axi_bvalid) 
            begin
              axi_bvalid <= 1'b0; 
            end  
        end
    end
end

// wready
always_ff @(posedge aclk, negedge aresetn) begin
  if ( aresetn == 1'b0 )
    begin
      axi_wready <= 1'b0;
    end 
  else
    begin    
      if (~axi_wready && axi_ctrl.wvalid && axi_ctrl.awvalid && aw_en )
        begin
          axi_wready <= 1'b1;
        end
      else
        begin
          axi_wready <= 1'b0;
        end
    end 
end  

// rvalid and rresp (1Del?)
always_ff @(posedge aclk, negedge aresetn) begin
  if ( aresetn == 1'b0 )
    begin
      axi_rvalid <= 0;
      axi_rresp  <= 0;
    end 
  else
    begin    
      if (axi_arready && axi_ctrl.arvalid && ~axi_rvalid)
        begin
          axi_rvalid <= 1'b1;
          axi_rresp  <= 2'b0;
        end   
      else if (axi_rvalid && axi_ctrl.rready)
        begin
          axi_rvalid <= 1'b0;
        end                
    end
end    

endmodule // cnfg_slave