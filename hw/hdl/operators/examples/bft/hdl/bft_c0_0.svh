/* -- Tie-off unused interfaces and signals ----------------------------- */
// always_comb axi_ctrl.tie_off_s();
// always_comb bpss_rd_req.tie_off_m();
// always_comb bpss_wr_req.tie_off_m();
// always_comb bpss_rd_done.tie_off_s();
// always_comb bpss_wr_done.tie_off_s();
// always_comb axis_host_0_sink.tie_off_s();
// always_comb axis_host_0_src.tie_off_m();
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

logic ap_clr, ap_clr_pulse, ap_start, ap_done;

logic [63:0] exp_tx_net_pkt, exp_rx_net_pkt, execution_cycles;

bft_tx_stat_t bft_tx_stat;
bft_rx_stat_t bft_rx_stat;

metaIntf #(.STYPE(logic [63:0])) buff_cmd();

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

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) tx_net_msg_s0();
metaIntf #(.STYPE(logic[64-1:0])) tx_net_meta_s0();

AXI4S #(.AXI4S_DATA_BITS(AXI_DATA_BITS)) rx_net_msg_s0();
metaIntf #(.STYPE(logic[64-1:0])) rx_net_meta_s0();

metaIntf #(.STYPE(64)) comm_meta_s0();
metaIntf #(.STYPE(64)) comm_meta_s1();

meta_reg_array #(.N_STAGES(2), .DATA_BITS(64)) inst_comm_meta_array (.aclk(aclk), .aresetn(aresetn), .s_meta(comm_meta_s0), .m_meta(comm_meta_s1));


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
    .netTxData(netTxData_reg),
    .netTxMeta(netTxMeta_reg),
    .netRxData(netRxData),
    .netRxMeta(netRxMeta),

    // TCP/IP QSFP0 CMD
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


ccl_engine ccl_engine
(
    .tx_data_in(tx_net_msg_s0),
    .tx_meta_in(tx_net_meta_s0),
    .net_tx_data_out(netTxData),
    .net_tx_meta_out(netTxMeta),
    .net_rx_data_in(netRxData_reg),
    .net_rx_meta_in(netRxMeta_reg),
    .rx_data_out(rx_net_msg_s0),
    .rx_meta_out(rx_net_meta_s0),
    .configComm_in(comm_meta_s1),
    .aclk(aclk),
    .aresetn(aresetn)
);

bench_role bench_role_inst
(
    // bench role control parameter
    .ap_start(ap_start),
    .ap_done(ap_done),
    .exp_tx_net_pkt(exp_tx_net_pkt),
    .exp_rx_net_pkt(exp_rx_net_pkt),
    .execution_cycles(execution_cycles),

    // TCP
    .tx_net_msg(tx_net_msg_s0),
    .tx_net_meta(tx_net_meta_s0),
    .rx_net_msg(rx_net_msg_s0),
    .rx_net_meta(rx_net_meta_s0),

    // Host
    .hostTxData(hostTxData),
    .hostTxMeta(hostTxMeta),

    .hostRxData(hostRxData),

    // debug
    .bft_tx_stat(bft_tx_stat),
    .bft_rx_stat(bft_rx_stat),

    // Clock and reset
    .aclk(aclk),
    .aresetn(aresetn)
);


bft_coyote_bench_slave bft_coyote_bench_slave_inst (
	.aclk           (aclk),
	.aresetn        (aresetn),
	.axi_ctrl       (axi_ctrl),
	.ap_clr         (ap_clr),
    .ap_start       (ap_start),
    .ap_done        (ap_done),

    // role parameter
    .exp_tx_net_pkt(exp_tx_net_pkt),
    .exp_rx_net_pkt(exp_rx_net_pkt),
    .execution_cycles(execution_cycles),

    // role debug
    .bft_tx_stat(bft_tx_stat),
    .bft_rx_stat(bft_rx_stat),

    // comm config cmd
    .comm_meta(comm_meta_s0),

    // intf buff cmd
    .buff_cmd(buff_cmd), 

    // intf config register
    .maxPkgWord (maxPkgWord),
    .batchMaxTimer(batchMaxTimer),

    // intf debug registers
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
