
	
package bftTypes;

    //`define DEBUG_BENCH_ROLE_SLAVE
    `define ILA_TCP_DEBUG
    `define ILA_HOST_DEBUG
    //`define DEBUG_CNFG_SLAVE
    //`define DEBUG_AUTH_ROLE
    //`define DEBUG_AUTH_PIPE
    //`define DEBUG_AUTH_HMAC


    parameter integer NET_OFFLOAD = 0; 
    parameter integer AUTH_OFFLOAD = 1; 

    parameter integer AUTH_DEBUG = 0;

    parameter integer NUM_AUTH_TX = 2;
    parameter integer NUM_AUTH_RX = 2;

    typedef struct packed {
        logic [31:0] totalRank;
        logic [31:0] epochID;
        logic [31:0] msgType;
        logic [31:0] msgID;
        logic [31:0] dataLen; //total byte len of data (payload+digest+auth) to each primitive
        logic [31:0] tag; // tag, reserved
        logic [31:0] src; // src rank
        logic [31:0] dst; // either dst rank or communicator ID depends on primitive
        logic [31:0] cmdLen; // total byte len of compulsory & optional cmd fields
        logic [31:0] cmdID; // specifier of different communication primitive
    } bft_hdr_t;

    typedef struct packed {
        logic [63:0] net_offload_bytes;
        logic [63:0] net_offload_pkt;
        logic [63:0] net_offload_down;
        logic [63:0] auth_offload_bytes;
        logic [63:0] auth_offload_pkt;
        logic [63:0] auth_offload_down;
    } bft_rx_stat_t;

    typedef struct packed {
        logic [63:0] net_offload_bytes;
        logic [63:0] net_offload_pkt;
        logic [63:0] net_offload_down;
        logic [63:0] auth_offload_bytes;
        logic [63:0] auth_offload_pkt;
        logic [63:0] auth_offload_down;
    } bft_tx_stat_t;

endpackage