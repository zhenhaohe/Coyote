`timescale 1ns / 1ps
	
import lynxTypes::*;

`include "axi_macros.svh"
`include "lynx_macros.svh"
	
module bft_ctrl_xbar (
    input  logic                            aclk,
    input  logic                            aresetn,

    AXI4L.s                                 s_axi_ctrl,
    
    AXI4L.m                                 m_axi_ctrl_cnfg,
    AXI4L.m                                 m_axi_ctrl_user
);

// ----------------------------------------------------------------------
// Control crossbar 
// ----------------------------------------------------------------------
logic[2*AXI_ADDR_BITS-1:0]       axi_xbar_araddr;
logic[5:0]                       axi_xbar_arprot;
logic[1:0]                       axi_xbar_arready;
logic[1:0]                       axi_xbar_arvalid;
logic[2*AXI_ADDR_BITS-1:0]       axi_xbar_awaddr;
logic[5:0]                       axi_xbar_awprot;
logic[1:0]                       axi_xbar_awready;
logic[1:0]                       axi_xbar_awvalid;
logic[1:0]                       axi_xbar_bready;
logic[3:0]                       axi_xbar_bresp;
logic[1:0]                       axi_xbar_bvalid;
logic[2*64-1:0]                  axi_xbar_rdata;
logic[1:0]                       axi_xbar_rready;
logic[3:0]                       axi_xbar_rresp;
logic[1:0]                       axi_xbar_rvalid;
logic[2*64-1:0]                  axi_xbar_wdata;
logic[1:0]                       axi_xbar_wready;
logic[2*(64/8)-1:0]              axi_xbar_wstrb;
logic[1:0]                       axi_xbar_wvalid;

// Route
assign m_axi_ctrl_cnfg.araddr                   = axi_xbar_araddr[2*AXI_ADDR_BITS-1:AXI_ADDR_BITS];
assign m_axi_ctrl_cnfg.arprot                   = axi_xbar_arprot[5:3];
assign m_axi_ctrl_cnfg.arvalid                  = axi_xbar_arvalid[1];
assign m_axi_ctrl_cnfg.awaddr                   = axi_xbar_awaddr[2*AXI_ADDR_BITS-1:AXI_ADDR_BITS];
assign m_axi_ctrl_cnfg.awprot                   = axi_xbar_awprot[5:3];
assign m_axi_ctrl_cnfg.awvalid                  = axi_xbar_awvalid[1];
assign m_axi_ctrl_cnfg.bready                   = axi_xbar_bready[1];
assign m_axi_ctrl_cnfg.rready                   = axi_xbar_rready[1];
assign m_axi_ctrl_cnfg.wdata                    = axi_xbar_wdata[2*64-1:64];
assign m_axi_ctrl_cnfg.wstrb                    = axi_xbar_wstrb[2*(64/8)-1:64/8];
assign m_axi_ctrl_cnfg.wvalid                   = axi_xbar_wvalid[1];

assign axi_xbar_arready[1]                      = m_axi_ctrl_cnfg.arready;
assign axi_xbar_awready[1]                      = m_axi_ctrl_cnfg.awready;
assign axi_xbar_bresp[3:2]                      = m_axi_ctrl_cnfg.bresp;
assign axi_xbar_bvalid[1]                       = m_axi_ctrl_cnfg.bvalid;
assign axi_xbar_rdata[2*64-1:64]                = m_axi_ctrl_cnfg.rdata;
assign axi_xbar_rresp[3:2]                      = m_axi_ctrl_cnfg.rresp;
assign axi_xbar_rvalid[1]                       = m_axi_ctrl_cnfg.rvalid;
assign axi_xbar_wready[1]                       = m_axi_ctrl_cnfg.wready;

assign m_axi_ctrl_user.araddr                   = axi_xbar_araddr[AXI_ADDR_BITS-1:0];
assign m_axi_ctrl_user.arprot                   = axi_xbar_arprot[2:0];
assign m_axi_ctrl_user.arvalid                  = axi_xbar_arvalid[0];
assign m_axi_ctrl_user.awaddr                   = axi_xbar_awaddr[AXI_ADDR_BITS-1:0];
assign m_axi_ctrl_user.awprot                   = axi_xbar_awprot[2:0];
assign m_axi_ctrl_user.awvalid                  = axi_xbar_awvalid[0];
assign m_axi_ctrl_user.bready                   = axi_xbar_bready[0];
assign m_axi_ctrl_user.rready                   = axi_xbar_rready[0];
assign m_axi_ctrl_user.wdata                    = axi_xbar_wdata[64-1:0];
assign m_axi_ctrl_user.wstrb                    = axi_xbar_wstrb[(64/8)-1:0];
assign m_axi_ctrl_user.wvalid                   = axi_xbar_wvalid[0];

assign axi_xbar_arready[0]                      = m_axi_ctrl_user.arready;
assign axi_xbar_awready[0]                      = m_axi_ctrl_user.awready;
assign axi_xbar_bresp[1:0]                      = m_axi_ctrl_user.bresp;
assign axi_xbar_bvalid[0]                       = m_axi_ctrl_user.bvalid;
assign axi_xbar_rdata[64-1:0]                   = m_axi_ctrl_user.rdata;
assign axi_xbar_rresp[1:0]                      = m_axi_ctrl_user.rresp;
assign axi_xbar_rvalid[0]                       = m_axi_ctrl_user.rvalid;
assign axi_xbar_wready[0]                       = m_axi_ctrl_user.wready;

axi_crossbar_bft inst_dyn_crossbar_bft (
    .aclk(aclk),                    
    .aresetn(aresetn),             
    .s_axi_awaddr(s_axi_ctrl.awaddr),    
    .s_axi_awprot(s_axi_ctrl.awprot),    
    .s_axi_awvalid(s_axi_ctrl.awvalid),  
    .s_axi_awready(s_axi_ctrl.awready),  
    .s_axi_wdata(s_axi_ctrl.wdata),      
    .s_axi_wstrb(s_axi_ctrl.wstrb),      
    .s_axi_wvalid(s_axi_ctrl.wvalid),    
    .s_axi_wready(s_axi_ctrl.wready),    
    .s_axi_bresp(s_axi_ctrl.bresp),      
    .s_axi_bvalid(s_axi_ctrl.bvalid),    
    .s_axi_bready(s_axi_ctrl.bready),    
    .s_axi_araddr(s_axi_ctrl.araddr),    
    .s_axi_arprot(s_axi_ctrl.arprot),    
    .s_axi_arvalid(s_axi_ctrl.arvalid),  
    .s_axi_arready(s_axi_ctrl.arready),  
    .s_axi_rdata(s_axi_ctrl.rdata),      
    .s_axi_rresp(s_axi_ctrl.rresp),      
    .s_axi_rvalid(s_axi_ctrl.rvalid),    
    .s_axi_rready(s_axi_ctrl.rready),    
    .m_axi_awaddr(axi_xbar_awaddr),    
    .m_axi_awprot(axi_xbar_awprot),    
    .m_axi_awvalid(axi_xbar_awvalid),  
    .m_axi_awready(axi_xbar_awready),  
    .m_axi_wdata(axi_xbar_wdata),      
    .m_axi_wstrb(axi_xbar_wstrb),      
    .m_axi_wvalid(axi_xbar_wvalid),    
    .m_axi_wready(axi_xbar_wready),    
    .m_axi_bresp(axi_xbar_bresp),      
    .m_axi_bvalid(axi_xbar_bvalid),    
    .m_axi_bready(axi_xbar_bready),    
    .m_axi_araddr(axi_xbar_araddr),    
    .m_axi_arprot(axi_xbar_arprot),    
    .m_axi_arvalid(axi_xbar_arvalid),  
    .m_axi_arready(axi_xbar_arready),  
    .m_axi_rdata(axi_xbar_rdata),      
    .m_axi_rresp(axi_xbar_rresp),      
    .m_axi_rvalid(axi_xbar_rvalid),    
    .m_axi_rready(axi_xbar_rready)
);

endmodule
