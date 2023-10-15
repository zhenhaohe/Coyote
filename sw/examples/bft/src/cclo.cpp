#include <iostream>
#include <fcntl.h>
#include <unistd.h>
#include <fstream>
#include <malloc.h>
#include <time.h> 
#include <sys/time.h>  
#include <chrono>
#include <iomanip>
#include <fcntl.h>
#include <vector>
#include <cstdint>

#include "cclo.hpp"
#include "buf.hpp"

using namespace std::chrono;


void CCLO::init_cclo(std::vector<comm_rank> rank_vec, unsigned int local_rank, unsigned int total_rank, uint64_t rxBatchMaxTimer, uint64_t pkgWordCount)
{
    // clear the hardware registers
    setClear();
    clearCompleted();

    cproc.setCSR(rxBatchMaxTimer, OFFSET_BFT_CRTL+BFT_CRTL::BATCH_MAX_TIMER);
    cproc.setCSR(pkgWordCount, OFFSET_BFT_CRTL+BFT_CRTL::MAX_PKG_WORD);

    printf("CCLO init communicator: world size:%x, local_rank:%x\n", total_rank, local_rank);

    comm.size = total_rank;
    comm.localRank = local_rank;
    comm.rank_vec = rank_vec;

    // arp lookup
    for(int i=0; i<total_rank; i++){
        if(local_rank != i){
            cproc.doArpLookup(rank_vec[i].ip);
        }
    }

    //open port 
    for (int i=0; i<total_rank; i++)
    {
        uint32_t dstPort = rank_vec[i].port;
        open_port(dstPort);
    }

    std::this_thread::sleep_for(10ms);

    //open con
    for (int i=0; i<total_rank; i++)
    {
        uint32_t dstPort = rank_vec[i].port;
        uint32_t dstIp = rank_vec[i].ip;
        uint32_t dstRank = i;
        std::cout<<"rank_vec:"<<dstPort<<" "<<dstIp<<" "<<dstRank<<std::endl;
        if (local_rank != dstRank)
        {
            open_connection(dstIp, dstPort, dstRank);
        }
    }

    // offload communicator
    std::cout<<"Offloading communicator..."<<std::endl;
    offload_communicator();

    // create receive buf
    for (int i=0; i<NUM_RX_BUF; i++){
        create_recvBuf(RX_BUF_SIZE);
    }

    std::cout<<"CCLO init done."<<std::endl;

}

void CCLO::open_port (unsigned int port)
{
    bool open_port_status;
    uint64_t open_port = port;
    open_port_status = cproc.tcpOpenPort(port);
}

void CCLO::open_connection (unsigned int dst_ip, unsigned int dst_port, unsigned int rank)
{
    // open connection
    bool success = false;
    uint32_t session = 0;

    comm.rank_vec[rank].ip = dst_ip;
    comm.rank_vec[rank].port = dst_port;
    printf("open_connection: dst ip:%x, dst port:%x, dst rank:%x\n", dst_ip, dst_port, rank);
    fflush(stdout);

    success = cproc.tcpOpenCon(dst_ip, dst_port, &session);

    if (success) {
        comm.rank_vec[rank].session = session;
    }
}


void CCLO::offload_communicator()
{
    uint32_t commTableEntry = comm.size;
    for(int i = 0; i < comm.size; i++)
    {
        uint16_t totalRank = comm.size;
        uint16_t localRank = comm.localRank;
        uint16_t currRank = i;
        uint16_t session = comm.rank_vec[i].session; 

        uint64_t commWord = 0;

        commWord |= static_cast<uint64_t>(totalRank);     // Pack totalRank at LSB
        commWord |= static_cast<uint64_t>(localRank) << 16;  // Shift localRank by 16 bits
        commWord |= static_cast<uint64_t>(currRank) << 32;  // Shift currRank by 32 bits
        commWord |= static_cast<uint64_t>(session) << 48;   // Shift session by 48 bits

        cout<<"commTable Entry:"<<hex<<i<<" "<<commWord<<endl;

        cproc.setCSR(commWord, OFFSET_BFT_CRTL+BFT_CRTL::COMMUNICATOR);
    }
    fflush(stdout);
}


// void CCLO::create_sendBuf (unsigned int bytes)
// {
//     buf_t curr_buf;
//     curr_buf.addr = getMem(bytes);
//     curr_buf.size = bytes;
//     curr_buf.head_offset = 0;
//     memset(curr_buf.addr,0,bytes); 
//     printf("Current send buf addr:%x\n", curr_buf.addr);
//     txHandler.buf_queue.push(curr_buf);
//     fflush(stdout);
// }


void CCLO::create_recvBuf (unsigned int bytes)
{
    if (rxHandler.buf_queue.size()>=8){
        std::cerr<<"HW Receive Buff CMD Overflow"<<std::endl;
        return;
    }
    buf_t curr_buf;
    curr_buf.addr = getMem(bytes);
    curr_buf.size = bytes;
    curr_buf.head_offset = 0;
    memset(curr_buf.addr,0,bytes); 
    rxHandler.buf_queue.push(curr_buf);
    printf("Current recv buf addr:%lx, Initial recv cnt:%d, buffer size:%d\n", (uint64_t)curr_buf.addr, rxHandler.curr_transfer_cnt, curr_buf.size);
    fflush(stdout);
    enqueue_recvBuf_hw(curr_buf);
}

void CCLO::enqueue_recvBuf_hw (buf_t curr_buf)
{   
    if (rxHandler.buf_queue.size()>=8){
        std::cerr<<"HW Receive Buff CMD Overflow"<<std::endl;
        return;
    }
    uint64_t buff_cmd;
    uint64_t buff_size_KB = (uint64_t) curr_buf.size / 1024;
    uint64_t addr = reinterpret_cast<uint64_t>(curr_buf.addr);
    buff_cmd = (addr & 0xFFFFFFFFFFFF)  |  ((buff_size_KB & 0xFFFF) << 48);
    cproc.setCSR(buff_cmd, OFFSET_BFT_CRTL+BFT_CRTL::BUFF_CMD);
}

rcv_meta_t CCLO::receive(void* user_buf, unsigned int user_buf_size)
{
    rcv_meta_t rcv_meta;
    
    uint32_t checkComplete;

    double durationUs = 0.0;
    
    //check new transfer
    rcv_meta.new_transfer = false;
    auto start = std::chrono::high_resolution_clock::now();
    while (!rcv_meta.new_transfer)
    {
        rcv_meta.new_transfer = false;
        checkComplete = checkFPGAWriteToHostCompleted();
        if( checkComplete > 0 && checkComplete > rxHandler.curr_transfer_cnt) {
            rcv_meta.new_transfer = true;
        } else {
            nanosleep((const struct timespec[]){{0, 10L}}, NULL);
        }
        auto end = std::chrono::high_resolution_clock::now();
        durationUs = (std::chrono::duration_cast<std::chrono::nanoseconds>(end-start).count() / 1000.0);
        if (durationUs > TIMEOUT_US && rcv_meta.new_transfer == false)
        {
            return rcv_meta;
        }
    }
    
    if (rcv_meta.new_transfer)
    {
        uint32_t numTransfer = checkComplete - rxHandler.curr_transfer_cnt;

        if (Verbose)
        {
            printf("Check complete:%d at bytes_offset:%d, curr_transfer_cnt:%d, new_transfer:%d, numTransfer:%d\n", checkComplete, rxHandler.curr_buf().head_offset, rxHandler.curr_transfer_cnt, rcv_meta.new_transfer, numTransfer);
            fflush(stdout);
        }

        for (size_t j = 0; j < numTransfer; j++) {
            // parse host intf batch header
            bufBatchHdr header;
            header.deserialize(reinterpret_cast<char*>(rxHandler.curr_buf().getHeadPointer()));

            if (Verbose)
            {
                header.printHeader();
            }

            // make sure seq number matches the curr_transfer_cnt
            if (header.seq != rxHandler.curr_transfer_cnt)
            {
                std::cerr<<"Mismatch: hardware seq: "<<header.seq<<" exp seq: "<<rxHandler.curr_transfer_cnt<<endl;
                break;
            }

            if ((rcv_meta.num_rcv_bytes) + header.total_bytes > user_buf_size){
                std::cerr<<"User buff full! user_buf_size:"<<user_buf_size<<" , recvd bytes:"<<(rcv_meta.num_rcv_bytes) + header.total_bytes<<endl;
                break;
            }

            rxHandler.curr_buf().head_offset += BUF_HDR_SIZE;

            memcpy(static_cast<char*>(user_buf) + (rcv_meta.num_rcv_bytes), rxHandler.curr_buf().getHeadPointer(), header.total_bytes);

            rxHandler.curr_buf().head_offset += header.total_bytes; 
            rxHandler.curr_transfer_cnt ++;

            rcv_meta.num_rcv_bytes += header.total_bytes;
            rcv_meta.num_rcv_msg += header.num_msg;

            // dequeue the current buffer
            // enqueue new buffer
            if (header.buf_full == 1)
            {
                buf_t curr_buf = rxHandler.curr_buf();
                rxHandler.buf_queue.pop();
                curr_buf.head_offset = 0;
                memset(curr_buf.addr, 0, curr_buf.size);
                rxHandler.buf_queue.push(curr_buf);
                enqueue_recvBuf_hw(curr_buf);
            }
        }
    } 
    
    return rcv_meta;
}


void CCLO::getDebugCounters()
{
    // intf debug counters
    sts_cnt.consumed_bytes_host = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::CONSUMED_BYTES_HOST);
    sts_cnt.produced_bytes_host = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::PRODUCED_BYTES_HOST);
    sts_cnt.consumed_bytes_network = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::CONSUMED_BYTES_NETWORK);
    sts_cnt.produced_bytes_network = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::PRODUCED_BYTES_NETWORK);
    sts_cnt.consumed_pkt_network = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::CONSUMED_PKT_NETWORK);
    sts_cnt.produced_pkt_network = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::PRODUCED_PKT_NETWORK);
    sts_cnt.consumed_pkt_host = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::CONSUMED_PKT_HOST);
    sts_cnt.produced_pkt_host = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::PRODUCED_PKT_HOST);
    sts_cnt.device_net_down = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::DEVICE_NET_DOWN);
    sts_cnt.net_device_down = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::NET_DEVICE_DOWN);
    sts_cnt.host_device_down = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::HOST_DEVICE_DOWN);
    sts_cnt.device_host_down = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::DEVICE_HOST_DOWN);
    sts_cnt.net_tx_cmd_error = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::NET_TX_CMD_ERROR);

    // bft debug counters
    sts_cnt.execution_cycles = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::EXECUTION_CYCLES);
    sts_cnt.rx_net_offload_pkt = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::RX_NET_OFFLOAD_PKT);
    sts_cnt.tx_net_offload_pkt = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::TX_NET_OFFLOAD_PKT);
    sts_cnt.rx_net_offload_bytes = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::RX_NET_OFFLOAD_BYTES);
    sts_cnt.tx_net_offload_bytes = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::TX_NET_OFFLOAD_BYTES);

    sts_cnt.rx_auth_offload_pkt = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::RX_AUTH_OFFLOAD_PKT);
    sts_cnt.tx_auth_offload_pkt = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::TX_AUTH_OFFLOAD_PKT);
    sts_cnt.rx_auth_offload_bytes = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::RX_AUTH_OFFLOAD_BYTES);
    sts_cnt.tx_auth_offload_bytes = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::TX_AUTH_OFFLOAD_BYTES);

    sts_cnt.tx_net_offload_down = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::TX_NET_OFFLOAD_DOWN);
    sts_cnt.rx_net_offload_down = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::RX_NET_OFFLOAD_DOWN);
    sts_cnt.tx_auth_offload_down = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::TX_AUTH_OFFLOAD_DOWN);
    sts_cnt.rx_auth_offload_down = cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::RX_AUTH_OFFLOAD_DOWN);
}

void CCLO::printKernelDebug()
{
    getDebugCounters();

    cout<<"consumed_bytes_host: "<<dec<<sts_cnt.consumed_bytes_host<<" produced_bytes_host: "<<sts_cnt.produced_bytes_host<<endl;
    cout<<"consumed_pkt_host: "<<dec<<sts_cnt.consumed_pkt_host<<" produced_pkt_host: "<<sts_cnt.produced_pkt_host<<endl;
    cout<<"tx_net_offload_bytes: "<<dec<<sts_cnt.tx_net_offload_bytes<<" rx_net_offload_bytes: "<<sts_cnt.rx_net_offload_bytes<<endl;
    cout<<"tx_net_offload_pkt: "<<dec<<sts_cnt.tx_net_offload_pkt<<" rx_net_offload_pkt: "<<sts_cnt.rx_net_offload_pkt<<endl;
    cout<<"tx_auth_offload_bytes: "<<dec<<sts_cnt.tx_auth_offload_bytes<<" rx_auth_offload_bytes: "<<sts_cnt.rx_auth_offload_bytes<<endl;
    cout<<"tx_auth_offload_pkt: "<<dec<<sts_cnt.tx_auth_offload_pkt<<" rx_auth_offload_pkt: "<<sts_cnt.rx_auth_offload_pkt<<endl;
    cout<<"produced_bytes_network: "<<dec<<sts_cnt.produced_bytes_network<<" consumed_bytes_network: "<<sts_cnt.consumed_bytes_network<<endl;
    cout<<"produced_pkt_network: "<<dec<<sts_cnt.produced_pkt_network<<" consumed_pkt_network: "<<sts_cnt.consumed_pkt_network<<endl;
    cout<<"host_device_down: "<<dec<<sts_cnt.host_device_down<<" device_host_down: "<<sts_cnt.device_host_down<<endl;
    cout<<"tx_net_offload_down: "<<dec<<sts_cnt.tx_net_offload_down<<" rx_net_offload_down: "<<sts_cnt.rx_net_offload_down<<endl;
    cout<<"tx_auth_offload_down: "<<dec<<sts_cnt.tx_auth_offload_down<<" rx_auth_offload_down: "<<sts_cnt.rx_auth_offload_down<<endl;
    cout<<"device_net_down: "<<dec<<sts_cnt.device_net_down<<" net_device_down: "<<sts_cnt.net_device_down<<endl;
    cout<<"net_tx_cmd_error: "<<dec<<sts_cnt.net_tx_cmd_error<<endl;
    fflush(stdout);
}

void CCLO::printKernelProfile()
{
    constexpr auto const freq = 250; // MHz

    getDebugCounters();

    double txNetThroughput = (double)sts_cnt.produced_bytes_network * 8.0 * freq / ((double)sts_cnt.execution_cycles*1000.0);
    double rxNetThroughput = (double)sts_cnt.consumed_bytes_network * 8.0 * freq / ((double)sts_cnt.execution_cycles*1000.0);
    double txHostThroughput = (double)sts_cnt.produced_bytes_host * 8.0 * freq / ((double)sts_cnt.execution_cycles*1000.0);
    double rxHostThroughput = (double)sts_cnt.consumed_bytes_host * 8.0 * freq / ((double)sts_cnt.execution_cycles*1000.0);
    double latency = (double)sts_cnt.execution_cycles / freq;
    double rxNetPktRate = (double) sts_cnt.consumed_pkt_network / ((double)latency/1000000.0);
    double txNetPktRate = (double) sts_cnt.produced_pkt_network / ((double)latency/1000000.0);
    double rxHostPktRate = (double) sts_cnt.consumed_pkt_host / ((double)latency/1000000.0);
    double txHostPktRate = (double) sts_cnt.produced_pkt_host / ((double)latency/1000000.0);
    cout<<"txNetThroughput [gbps]: "<<txNetThroughput<<" rxNetThroughput [gbps]: "<<rxNetThroughput<<" hwTime[us]: "<<latency<<endl;
    cout<<"txHostThroughput [gbps]: "<<txHostThroughput<<" rxHostThroughput [gbps]: "<<rxHostThroughput<<" hwTime[us]: "<<latency<<endl;
    cout<<"txNetPktRate : "<<txNetPktRate<<" rxNetPktRate : "<<rxNetPktRate<<endl;
    cout<<"txHostPktRate : "<<txHostPktRate<<" rxHostPktRate : "<<rxHostPktRate<<endl;
    fflush(stdout);
}

std::string CCLO::format_log(std::string exp, unsigned int totalRank, unsigned int localRank, unsigned int pkgWordCount, unsigned int payloadSize, unsigned int numMsg, unsigned int authenticatorLen, unsigned int txBatchNum, unsigned int rxBatchMaxTimer, unsigned int parallel_threads)
{
    constexpr auto const freq = 250; // MHz

    getDebugCounters();

    double txNetThroughput = (double)sts_cnt.produced_bytes_network * 8.0 * freq / ((double)sts_cnt.execution_cycles*1000.0);
    double rxNetThroughput = (double)sts_cnt.consumed_bytes_network * 8.0 * freq / ((double)sts_cnt.execution_cycles*1000.0);
    double txHostThroughput = (double)sts_cnt.produced_bytes_host * 8.0 * freq / ((double)sts_cnt.execution_cycles*1000.0);
    double rxHostThroughput = (double)sts_cnt.consumed_bytes_host * 8.0 * freq / ((double)sts_cnt.execution_cycles*1000.0);
    double latency = (double)sts_cnt.execution_cycles / freq;
    double rxNetPktRate = (double) sts_cnt.consumed_pkt_network / ((double)latency/1000000.0);
    double txNetPktRate = (double) sts_cnt.produced_pkt_network / ((double)latency/1000000.0);
    double rxHostPktRate = (double) sts_cnt.consumed_pkt_host / ((double)latency/1000000.0);
    double txHostPktRate = (double) sts_cnt.produced_pkt_host / ((double)latency/1000000.0);

    std::string head_str = "exp,totalRank,localRank,pkgWordCount,payloadSize,numMsg,authenticatorLen,txBatchNum,rxBatchMaxTimer,consumed_bytes_host,produced_bytes_host,consumed_bytes_network,produced_bytes_network,consumed_pkt_network,produced_pkt_network,consumed_pkt_host,produced_pkt_host,execution_cycles,rx_net_offload_pkt,tx_net_offload_pkt,device_net_down,net_device_down,host_device_down,device_host_down,net_tx_cmd_error,txNetThroughput[Gbps],rxNetThroughput[Gbps],txHostThroughput[Gbps],rxHostThroughput[Gbps],rxNetPktRate[pps],txNetPktRate[pps],rxHostPktRate[pps],txHostPktRate[pps],latency,parallel_threads";

	std::string value_str = exp + "," + std::to_string(totalRank) + "," + std::to_string(localRank) + "," + std::to_string(pkgWordCount) + "," + std::to_string(payloadSize) + "," + std::to_string(numMsg) + "," + std::to_string(authenticatorLen) + "," + std::to_string(txBatchNum) + "," + std::to_string(rxBatchMaxTimer) + "," + std::to_string(sts_cnt.consumed_bytes_host) + "," + std::to_string(sts_cnt.produced_bytes_host)+ "," + std::to_string(sts_cnt.consumed_bytes_network) + "," + std::to_string(sts_cnt.produced_bytes_network) + "," + std::to_string(sts_cnt.consumed_pkt_network) + "," + std::to_string(sts_cnt.produced_pkt_network) + "," + std::to_string(sts_cnt.consumed_pkt_host) + "," + std::to_string(sts_cnt.produced_pkt_host) + "," + std::to_string(sts_cnt.execution_cycles) + "," + std::to_string(sts_cnt.rx_net_offload_pkt) + "," + std::to_string(sts_cnt.tx_net_offload_pkt) + "," + std::to_string(sts_cnt.device_net_down) + "," + std::to_string(sts_cnt.net_device_down) + "," + std::to_string(sts_cnt.host_device_down) + "," + std::to_string(sts_cnt.device_host_down) + "," + std::to_string(sts_cnt.net_tx_cmd_error) + "," + std::to_string(txNetThroughput) + "," + std::to_string(rxNetThroughput) + "," + std::to_string(txHostThroughput) + "," + std::to_string(rxHostThroughput) + "," + std::to_string(rxNetPktRate) + "," + std::to_string(txNetPktRate) + "," + std::to_string(rxHostPktRate) + "," + std::to_string(txHostPktRate) + "," + std::to_string(latency) + "," + std::to_string(parallel_threads);

    std::string log_str = head_str + '\n' + value_str;
	return log_str;
}
    


