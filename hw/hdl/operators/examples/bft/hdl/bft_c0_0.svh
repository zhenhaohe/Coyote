/* -- Tie-off unused interfaces and signals ----------------------------- */
// always_comb axi_ctrl.tie_off_s();
// always_comb bpss_rd_req.tie_off_m();
// always_comb bpss_wr_req.tie_off_m();
// always_comb bpss_rd_done.tie_off_s();
// always_comb bpss_wr_done.tie_off_s();
// always_comb axis_host_0_sink.tie_off_s();
// always_comb axis_host_0_src.tie_off_m();
// always_comb tcp_0_listen_req.tie_off_m();
// always_comb tcp_0_listen_rsp.tie_off_s();
// always_comb tcp_0_open_req.tie_off_m();
// always_comb tcp_0_open_rsp.tie_off_s();
// always_comb tcp_0_close_req.tie_off_m();
// always_comb tcp_0_notify.tie_off_s();
// always_comb tcp_0_rd_pkg.tie_off_m();
// always_comb tcp_0_rx_meta.tie_off_s();
// always_comb tcp_0_tx_meta.tie_off_m();
// always_comb tcp_0_tx_stat.tie_off_s();
// always_comb axis_tcp_0_sink.tie_off_s();
// always_comb axis_tcp_0_src.tie_off_m();

/* -- USER LOGIC -------------------------------------------------------- */
logic [63:0]  	consumed_bytes_network, consumed_bytes_host ;
logic [63:0]  	produced_bytes_network, produced_bytes_host ;
logic [63:0]  	produced_pkt_network, consumed_pkt_network;
logic [63:0]  	produced_pkt_host, consumed_pkt_host;
logic [63:0]    device_host_down, host_device_down;
logic [63:0]    net_device_down, device_net_down;
logic [63:0]    net_tx_cmd_error;

logic [63:0]	maxPkgWord;
logic [63:0]    batchMaxTimer;

logic ap_clr, ap_clr_pulse;

metaIntf #(.STYPE(logic [63:0])) buff_cmd();

metaIntf #(.STYPE(logic [63:0])) open_con_cmd();
metaIntf #(.STYPE(logic [31:0])) open_port_cmd();
metaIntf #(.STYPE(logic [31:0])) close_con_cmd();
metaIntf #(.STYPE(logic [127:0])) open_con_sts();
metaIntf #(.STYPE(logic [31:0])) open_port_sts();

AXI4S #(.AXI4S_DATA_BITS(512)) netTxData();
metaIntf #(.STYPE(logic [63:0])) netTxMeta();
AXI4S #(.AXI4S_DATA_BITS(512)) netRxData();
metaIntf #(.STYPE(logic [63:0])) netRxMeta();

AXI4S #(.AXI4S_DATA_BITS(512)) netTxData_reg();
metaIntf #(.STYPE(logic [63:0])) netTxMeta_reg();
AXI4S #(.AXI4S_DATA_BITS(512)) netRxData_reg();
metaIntf #(.STYPE(logic [63:0])) netRxMeta_reg();

AXI4SR #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) hostRxData();

AXI4S #(.AXI4S_DATA_BITS(512)) hostTxData();
metaIntf #(.STYPE(logic [63:0])) hostTxMeta();

AXI4SR #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) axis_host_0_sink_reg();
axisr_reg_array #(.N_STAGES(2)) inst_axis_host_0_sink_reg_array (.aclk(aclk), .aresetn(aresetn), .s_axis(axis_host_0_sink), .m_axis(axis_host_0_sink_reg));

AXI4SR #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) axis_host_0_src_reg();
axisr_reg_array #(.N_STAGES(2)) inst_axis_host_0_src_reg_array (.aclk(aclk), .aresetn(aresetn), .s_axis(axis_host_0_src_reg), .m_axis(axis_host_0_src));

host_wrapper host_intf_wrapper_inst(
    // DESCRIPTOR BYPASS
    .bpss_rd_req(bpss_rd_req),
    .bpss_wr_req(bpss_wr_req),
    .bpss_rd_done(bpss_rd_done),
    .bpss_wr_done(bpss_wr_done),

    // AXI4S HOST STREAMS
    .axis_host_0_sink(axis_host_0_sink_reg),
    .axis_host_0_src(axis_host_0_src_reg),

    //User interface
    .device2host(hostTxData),
    .device2host_meta(hostTxMeta),

    .host2device(hostRxData),

    // Runtime Parameter
    .ap_clr_pulse(ap_clr_pulse),
    .batchMaxTimer(batchMaxTimer),
    
    .buff_cmd(buff_cmd),

    // debug registers
    .consumed_bytes_host(consumed_bytes_host),
    .produced_bytes_host(produced_bytes_host),
    .produced_pkt_host(produced_pkt_host),
    .consumed_pkt_host(consumed_pkt_host),
    .host_device_down(host_device_down),
    .device_host_down(device_host_down),
    
    // Clock and reset
    .aclk(aclk),
    .aresetn(aresetn)
);

axis_reg_array #(.N_STAGES(5)) inst_netRxData_reg_array (.aclk(aclk), .aresetn(aresetn), .s_axis(netRxData), .m_axis(netRxData_reg));
meta_reg_array #(.N_STAGES(5), .DATA_BITS(64)) inst_netRxMeta_reg_array (.aclk(aclk), .aresetn(aresetn), .s_meta(netRxMeta), .m_meta(netRxMeta_reg));
axis_reg_array #(.N_STAGES(5)) inst_netTxData_reg_array (.aclk(aclk), .aresetn(aresetn), .s_axis(netTxData), .m_axis(netTxData_reg));
meta_reg_array #(.N_STAGES(5), .DATA_BITS(64)) inst_netTxMeta_reg_array (.aclk(aclk), .aresetn(aresetn), .s_meta(netTxMeta), .m_meta(netTxMeta_reg));

tcp_wrapper tcp_intf_wrapper_inst(
    // control
    .ap_clr_pulse(ap_clr_pulse),
    .maxPkgWord(maxPkgWord),
    
    // User Interface
    .open_con_cmd(open_con_cmd),
    .open_port_cmd(open_port_cmd),
    .close_con_cmd(close_con_cmd),
    .open_con_sts(open_con_sts),
    .open_port_sts(open_port_sts),
    .netTxData(netTxData_reg),
    .netTxMeta(netTxMeta_reg),
    .netRxData(netRxData),
    .netRxMeta(netRxMeta),

    // TCP/IP QSFP0 CMD
    .tcp_0_listen_req(tcp_0_listen_req),
    .tcp_0_listen_rsp(tcp_0_listen_rsp),
    .tcp_0_open_req(tcp_0_open_req),
    .tcp_0_open_rsp(tcp_0_open_rsp),
    .tcp_0_close_req(tcp_0_close_req),
    .tcp_0_notify(tcp_0_notify),
    .tcp_0_rd_pkg(tcp_0_rd_pkg),
    .tcp_0_rx_meta(tcp_0_rx_meta),
    .tcp_0_tx_meta(tcp_0_tx_meta),
    .tcp_0_tx_stat(tcp_0_tx_stat),

    // AXI4S TCP/IP QSFP0 STREAMS
    .axis_tcp_0_sink(axis_tcp_0_sink),
    .axis_tcp_0_src(axis_tcp_0_src),

    // debug registers
    .consumed_bytes_network(consumed_bytes_network),
    .produced_bytes_network(produced_bytes_network),
    .produced_pkt_network(produced_pkt_network),
    .consumed_pkt_network(consumed_pkt_network),
    .device_net_down(device_net_down),
    .net_device_down(net_device_down),
    .net_tx_cmd_error(net_tx_cmd_error),

    // Clock and reset
    .aclk(aclk),
    .aresetn(aresetn)
);

// Control crossbar 
AXI4L #(.AXI4L_DATA_BITS(64)) axi_ctrl_cnfg ();
AXI4L #(.AXI4L_DATA_BITS(64)) axi_ctrl_user ();

bft_ctrl_xbar bft_ctrl_xbar_inst (
    .aclk(aclk),
    .aresetn(aresetn),
    .s_axi_ctrl(axi_ctrl),
    .m_axi_ctrl_cnfg(axi_ctrl_cnfg),
    .m_axi_ctrl_user(axi_ctrl_user)
);


bench_role bench_role_inst
(
    // control
    .s_axi_ctrl(axi_ctrl_user),

    // TCP
    .netTxData(netTxData),
    .netTxMeta(netTxMeta),
    .netRxData(netRxData_reg),
    .netRxMeta(netRxMeta_reg),

    // Host
    .hostTxData(hostTxData),
    .hostTxMeta(hostTxMeta),

    .hostRxData(hostRxData),

    // Clock and reset
    .aclk(aclk),
    .aresetn(aresetn)
);


bft_coyote_bench_slave bft_coyote_bench_slave_inst (
	.aclk         (aclk),
	.aresetn      (aresetn),
	.axi_ctrl     (axi_ctrl_cnfg),
	.ap_clr     (ap_clr),
	.open_con_cmd_tdata (open_con_cmd.data), //[31:0] ip, [47:32] port
	.open_con_cmd_tvalid (open_con_cmd.valid),
	.open_con_cmd_tready (open_con_cmd.ready),
	.open_port_cmd_tdata (open_port_cmd.data), //[15:0] port
	.open_port_cmd_tvalid (open_port_cmd.valid),
	.open_port_cmd_tready (open_port_cmd.ready),
	.close_con_cmd_tdata (close_con_cmd.data), // [15:0] session
	.close_con_cmd_tvalid (close_con_cmd.valid),
	.close_con_cmd_tready (close_con_cmd.ready),
	.open_con_sts_tdata (open_con_sts.data), // [15:0] session, [23:16] success, [55:24] ip, [71:56] port
	.open_con_sts_tvalid (open_con_sts.valid),
	.open_con_sts_tready (open_con_sts.ready),
	.open_port_sts_tdata (open_port_sts.data), // [7:0] success
	.open_port_sts_tvalid (open_port_sts.valid),
	.open_port_sts_tready (open_port_sts.ready),
    .buff_cmd_tdata(buff_cmd.data), // [47:0] base address offset, [63:48] size in KB
    .buff_cmd_tvalid(buff_cmd.valid),
    .buff_cmd_tready(buff_cmd.ready),

    // config register
    .maxPkgWord (maxPkgWord),
    .batchMaxTimer(batchMaxTimer),

    // debug registers
	.consumed_bytes_network (consumed_bytes_network),
	.produced_bytes_network (produced_bytes_network),
	.consumed_bytes_host(consumed_bytes_host),
	.produced_bytes_host(produced_bytes_host),
	.consumed_pkt_network(consumed_pkt_network),
	.produced_pkt_network(produced_pkt_network),
	.consumed_pkt_host(consumed_pkt_host),
	.produced_pkt_host(produced_pkt_host),
    .host_device_down(host_device_down),
    .device_host_down(device_host_down),
    .net_device_down(net_device_down),
    .device_net_down(device_net_down),
    .net_tx_cmd_error(net_tx_cmd_error)
);

// create pulse when ap_clr transitions to 1
logic ap_clr_r = 1'b0;

always @(posedge aclk) begin
  begin
    ap_clr_r <= ap_clr;
  end
end

assign ap_clr_pulse = ap_clr & ~ap_clr_r;
