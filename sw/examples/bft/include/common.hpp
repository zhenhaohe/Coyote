#pragma once

const size_t OFFSET_BFT_CRTL  = 0x0000; 

namespace BFT_CRTL {
	constexpr auto const START = 0;
	constexpr auto const STATUS = 1;
	constexpr auto const CLEAR = 2;
	constexpr auto const CONSUMED_BYTES_NETWORK = 7;
	constexpr auto const PRODUCED_BYTES_NETWORK = 8;
	constexpr auto const MAX_PKG_WORD = 11;
	constexpr auto const CONSUMED_BYTES_HOST = 12;
	constexpr auto const PRODUCED_BYTES_HOST = 13;
	constexpr auto const CONSUMED_PKT_NETWORK = 16;
	constexpr auto const PRODUCED_PKT_NETWORK = 17;
	constexpr auto const CONSUMED_PKT_HOST = 18;
	constexpr auto const PRODUCED_PKT_HOST = 19;
	constexpr auto const BATCH_MAX_TIMER = 25;
	constexpr auto const DEVICE_NET_DOWN = 26;
	constexpr auto const NET_DEVICE_DOWN = 27;
	constexpr auto const HOST_DEVICE_DOWN = 28;
	constexpr auto const DEVICE_HOST_DOWN = 29;
	constexpr auto const NET_TX_CMD_ERROR = 30;
	constexpr auto const BUFF_CMD = 31;

	constexpr auto const TX_NET_OFFLOAD_BYTES = 32;
	constexpr auto const TX_NET_OFFLOAD_PKT = 33;
	constexpr auto const TX_NET_OFFLOAD_DOWN = 34;
	constexpr auto const TX_AUTH_OFFLOAD_BYTES = 35;
	constexpr auto const TX_AUTH_OFFLOAD_PKT = 36;
	constexpr auto const TX_AUTH_OFFLOAD_DOWN = 37;
	constexpr auto const RX_NET_OFFLOAD_BYTES = 38;
	constexpr auto const RX_NET_OFFLOAD_PKT = 39;
	constexpr auto const RX_NET_OFFLOAD_DOWN = 40;
	constexpr auto const RX_AUTH_OFFLOAD_BYTES = 41;
	constexpr auto const RX_AUTH_OFFLOAD_PKT = 42;
	constexpr auto const RX_AUTH_OFFLOAD_DOWN = 43;
	constexpr auto const EXECUTION_CYCLES = 44;
	constexpr auto const EXP_TX_NET_PKT = 45;
	constexpr auto const EXP_RX_NET_PKT = 46;
	constexpr auto const COMMUNICATOR = 47;
}

typedef struct {
	// intf debug counters
    uint64_t consumed_bytes_host;
    uint64_t produced_bytes_host;
    uint64_t consumed_bytes_network;
    uint64_t produced_bytes_network;
    uint64_t consumed_pkt_network;
    uint64_t produced_pkt_network;
    uint64_t consumed_pkt_host;
    uint64_t produced_pkt_host;
    uint64_t device_net_down;
    uint64_t net_device_down;
    uint64_t host_device_down;
    uint64_t device_host_down;
    uint64_t net_tx_cmd_error;

    // bft debug counters
    uint64_t execution_cycles;
    uint64_t rx_net_offload_pkt;
    uint64_t tx_net_offload_pkt;
    uint64_t rx_net_offload_bytes;
    uint64_t tx_net_offload_bytes;

    uint64_t rx_auth_offload_pkt;
    uint64_t tx_auth_offload_pkt;
    uint64_t rx_auth_offload_bytes;
    uint64_t tx_auth_offload_bytes;

    uint64_t tx_net_offload_down;
    uint64_t rx_net_offload_down;
    uint64_t tx_auth_offload_down;
    uint64_t rx_auth_offload_down;
} debug_type;