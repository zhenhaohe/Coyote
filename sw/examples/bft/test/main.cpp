#include <iostream>
#include <string>
#include <malloc.h>
#include <time.h> 
#include <sys/time.h>  
#include <chrono>
#include <fstream>
#include <fcntl.h>
#include <unistd.h>
#include <iomanip>
#include <random>
#include <thread>
#include <mpi.h>


//#include <x86intrin.h>

#include <boost/program_options.hpp>

#include "cDefs.hpp"
#include "cclo.hpp"
#include "common.hpp"
#include "bft.hpp"
#include "buf.hpp"

using namespace std;
using namespace std::chrono;
using namespace fpga;

int mpi_rank, mpi_size;

/* Runtime */
constexpr auto const targetRegion = 0;
constexpr auto const freq = 250; // MHz

struct options_t
{
    uint32_t localIp; 
    uint64_t totalRank;
    uint64_t pkgWordCount;
    uint64_t localRank;
    uint64_t payloadSize;
    uint64_t numMsg;
    uint32_t authenticatorLen;
    uint32_t masterRank;
    uint64_t txBatchNum;
    uint64_t rxBatchMaxTimer;
    char* sendBuf;
    uint32_t sendBufSize;
    char* recvBuf;
    uint32_t recvBufSize;
    uint32_t msgBytes;
    uint32_t msgBytesR;
    uint64_t offloadMode;

	std::string logDir;
    std::string fpgaIpStr;
};


uint32_t ip_str_to_uint(std::string ip_str)
{
    std::string s = ip_str;
    std::string delimiter = ".";
    int ip [4];
    size_t pos = 0;
    std::string token;
    int i = 0;
    while ((pos = s.find(delimiter)) != std::string::npos) {
        token = s.substr(0, pos);
        ip [i] = stoi(token);
        s.erase(0, pos + delimiter.length());
        i++;
    }
    ip[i] = stoi(s); 
    uint32_t local_IP = ip[3] | (ip[2] << 8) | (ip[1] << 16) | (ip[0] << 24);
    return local_IP;
}

void parse_ip_list_str (std::string fpgaIpStr, std::vector<uint32_t>& fpgaIPList)
{
    std::string s = fpgaIpStr;
    std::string delimiter = ",";
    size_t pos = 0;
    std::string token;
    while ((pos = s.find(delimiter)) != std::string::npos) {
        token = s.substr(0, pos);
        // std::cout << token << std::endl;
        uint32_t ip = ip_str_to_uint(token);   
        fpgaIPList.push_back(ip);
        s.erase(0, pos + delimiter.length());
    }
    // std::cout << s << std::endl;
    uint32_t ip = ip_str_to_uint(s);   
    fpgaIPList.push_back(ip);
}

void print_log(std::string logDir, int rank, const std::string &message) {
  std::string str_rank = std::to_string(rank);
  std::string filename = logDir + std::string("/rank") + str_rank + std::string(".log");
  std::ofstream outfile;
  std::cout<<"logfile name:"<<filename<<std::endl;
  outfile.open(filename, std::ios::out | std::ios_base::app);
  outfile << message << std::endl;
  outfile.close();
}

std::string format_log(CCLO* cproc, std::string exp, options_t options)
{
    constexpr auto const freq = 250; // MHz
    
    uint64_t consumed_bytes_host = cproc->getCSR(OFFSET_BFT_CRTL+BFT_CRTL::CONSUMED_BYTES_HOST);
    uint64_t produced_bytes_host = cproc->getCSR(OFFSET_BFT_CRTL+BFT_CRTL::PRODUCED_BYTES_HOST);
    uint64_t consumed_bytes_network = cproc->getCSR(OFFSET_BFT_CRTL+BFT_CRTL::CONSUMED_BYTES_NETWORK);
    uint64_t produced_bytes_network = cproc->getCSR(OFFSET_BFT_CRTL+BFT_CRTL::PRODUCED_BYTES_NETWORK);
    uint64_t consumed_pkt_network = cproc->getCSR(OFFSET_BFT_CRTL+BFT_CRTL::CONSUMED_PKT_NETWORK);
    uint64_t produced_pkt_network = cproc->getCSR(OFFSET_BFT_CRTL+BFT_CRTL::PRODUCED_PKT_NETWORK);
    uint64_t consumed_pkt_host = cproc->getCSR(OFFSET_BFT_CRTL+BFT_CRTL::CONSUMED_PKT_HOST);
    uint64_t produced_pkt_host = cproc->getCSR(OFFSET_BFT_CRTL+BFT_CRTL::PRODUCED_PKT_HOST);
    uint64_t device_net_down = cproc->getCSR(OFFSET_BFT_CRTL+BFT_CRTL::DEVICE_NET_DOWN);
    uint64_t net_device_down = cproc->getCSR(OFFSET_BFT_CRTL+BFT_CRTL::NET_DEVICE_DOWN);
    uint64_t host_device_down = cproc->getCSR(OFFSET_BFT_CRTL+BFT_CRTL::HOST_DEVICE_DOWN);
    uint64_t device_host_down = cproc->getCSR(OFFSET_BFT_CRTL+BFT_CRTL::DEVICE_HOST_DOWN);
    uint64_t net_tx_cmd_error = cproc->getCSR(OFFSET_BFT_CRTL+BFT_CRTL::NET_TX_CMD_ERROR);

    uint64_t execution_cycles = cproc->getCSR(OFFSET_BFT_CRTL+BFT_CRTL::EXECUTION_CYCLES);

    double txNetThroughput = (double)produced_bytes_network * 8.0 * freq / ((double)execution_cycles*1000.0);
    double rxNetThroughput = (double)consumed_bytes_network * 8.0 * freq / ((double)execution_cycles*1000.0);
    double txHostThroughput = (double)produced_bytes_host * 8.0 * freq / ((double)execution_cycles*1000.0);
    double rxHostThroughput = (double)consumed_bytes_host * 8.0 * freq / ((double)execution_cycles*1000.0);
    double latency = (double)execution_cycles / freq;
    double rxNetPktRate = (double) consumed_pkt_network / ((double)latency/1000000.0);
    double txNetPktRate = (double) produced_pkt_network / ((double)latency/1000000.0);
    double rxHostPktRate = (double) consumed_pkt_host / ((double)latency/1000000.0);
    double txHostPktRate = (double) produced_pkt_host / ((double)latency/1000000.0);
    std::string head_str = "exp,totalRank,localRank,pkgWordCount,payloadSize,numMsg,authenticatorLen,txBatchNum,rxBatchMaxTimer,consumed_bytes_host,produced_bytes_host,consumed_bytes_network,produced_bytes_network,consumed_pkt_network,produced_pkt_network,consumed_pkt_host,produced_pkt_host,execution_cycles,consumed_pkt_network,produced_pkt_network,device_net_down,net_device_down,host_device_down,device_host_down,net_tx_cmd_error,txNetThroughput[Gbps],rxNetThroughput[Gbps],txHostThroughput[Gbps],rxHostThroughput[Gbps],rxNetPktRate[pps],txNetPktRate[pps],rxHostPktRate[pps],txHostPktRate[pps],latency,offloadMode";

	std::string value_str = exp + "," + std::to_string(options.totalRank) + "," + std::to_string(options.localRank) + "," + std::to_string(options.pkgWordCount) + "," + std::to_string(options.payloadSize) + "," + std::to_string(options.numMsg) + "," + std::to_string(options.authenticatorLen) + "," + std::to_string(options.txBatchNum) + "," + std::to_string(options.rxBatchMaxTimer) + "," + std::to_string(consumed_bytes_host) + "," + std::to_string(produced_bytes_host)+ "," + std::to_string(consumed_bytes_network) + "," + std::to_string(produced_bytes_network) + "," + std::to_string(consumed_pkt_network) + "," + std::to_string(produced_pkt_network) + "," + std::to_string(consumed_pkt_host) + "," + std::to_string(produced_pkt_host) + "," + std::to_string(execution_cycles) + "," + std::to_string(consumed_pkt_network) + "," + std::to_string(produced_pkt_network) + "," + std::to_string(device_net_down) + "," + std::to_string(net_device_down) + "," + std::to_string(host_device_down) + "," + std::to_string(device_host_down) + "," + std::to_string(net_tx_cmd_error) + "," + std::to_string(txNetThroughput) + "," + std::to_string(rxNetThroughput) + "," + std::to_string(txHostThroughput) + "," + std::to_string(rxHostThroughput) + "," + std::to_string(rxNetPktRate) + "," + std::to_string(txNetPktRate) + "," + std::to_string(rxHostPktRate) + "," + std::to_string(txHostPktRate) + "," + std::to_string(latency) + "," + std::to_string(options.offloadMode);

    std::string log_str = head_str + '\n' + value_str;
	return log_str;
}


void one_to_all_test(CCLO* cclo, options_t opts)
{
    std::cout<<"one_to_all_test"<<std::endl;

    // // set runtime parameters
    uint64_t exp_tx_net_pkt;
    uint64_t exp_rx_net_pkt;

    // bcast-scatter from master rank
    if (opts.localRank == opts.masterRank)
    {
        exp_tx_net_pkt = opts.numMsg * (opts.totalRank-1);
        cclo->setCSR(0, OFFSET_BFT_CRTL+BFT_CRTL::EXP_RX_NET_PKT);
        cclo->setCSR(exp_tx_net_pkt, OFFSET_BFT_CRTL+BFT_CRTL::EXP_TX_NET_PKT);
        
    }
    else 
    {
        exp_rx_net_pkt = opts.numMsg;
        cclo->setCSR(exp_rx_net_pkt, OFFSET_BFT_CRTL+BFT_CRTL::EXP_RX_NET_PKT);
        cclo->setCSR(0, OFFSET_BFT_CRTL+BFT_CRTL::EXP_TX_NET_PKT);
    }

    double durationUs = 0.0;
    auto start = std::chrono::high_resolution_clock::now();

    //set the control bit to start the kernel
    cclo->startKernel(); 

    if(opts.localRank == opts.masterRank)
    {
        // transfer data
        for (int i = 0; i< opts.numMsg/opts.txBatchNum; i++)
        {
            cclo->invokeHostWriteToFPGA(opts.sendBuf, opts.sendBufSize);
        }
    }

    //Probe the done signal
    // while (cclo->getCSR(1) != 1)
    // {
    //     auto end = std::chrono::high_resolution_clock::now();
    //     durationUs = (std::chrono::duration_cast<std::chrono::nanoseconds>(end-start).count() / 1000.0);
    //     if (durationUs > 6000000) break;
    // }
    
    std::this_thread::sleep_for(6s);
    
    auto end = std::chrono::high_resolution_clock::now();
    durationUs = (std::chrono::duration_cast<std::chrono::nanoseconds>(end-start).count() / 1000.0);
    std::cout<<"Experiment finished durationUs:"<<durationUs<<std::endl;

    // Print net stats
    cclo->printDebug();
    cclo->printKernelDebug();
    cclo->printKernelProfile();

    print_log(opts.logDir, opts.localRank, format_log(cclo, "one_to_all", opts));

    // // Verification
    // if(opts.localRank != opts.masterRank)
    // {
    //     polling_and_deserialization(cclo, opts);
    // }
}

void all_to_all_test(CCLO* cclo, options_t opts)
{
    std::cout<<"all_to_all_test"<<std::endl;

    // // set runtime parameters
    uint64_t exp_tx_net_pkt;
    uint64_t exp_rx_net_pkt;

    exp_rx_net_pkt = opts.numMsg * (opts.totalRank-1);
    cclo->setCSR(exp_rx_net_pkt, OFFSET_BFT_CRTL+BFT_CRTL::EXP_RX_NET_PKT);
    cclo->setCSR(0, OFFSET_BFT_CRTL+BFT_CRTL::EXP_TX_NET_PKT);
    
    double durationUs = 0.0;
    auto start = std::chrono::high_resolution_clock::now();

    //set the control bit to start the kernel
    cclo->startKernel(); 

    // transfer data
    for (int i = 0; i< opts.numMsg/opts.txBatchNum; i++)
    {
        cclo->invokeHostWriteToFPGA(opts.sendBuf, opts.sendBufSize);
    }

    //Probe the done signal
    // while (cclo->getCSR(1) != 1)
    // {
    //     auto end = std::chrono::high_resolution_clock::now();
    //     durationUs = (std::chrono::duration_cast<std::chrono::nanoseconds>(end-start).count() / 1000.0);
    //     if (durationUs > 6000000) break;
    // }
    
    std::this_thread::sleep_for(6s);

    auto end = std::chrono::high_resolution_clock::now();
    durationUs = (std::chrono::duration_cast<std::chrono::nanoseconds>(end-start).count() / 1000.0);
    std::cout<<"Experiment finished durationUs:"<<durationUs<<std::endl;

    // Print net stats
    cclo->printDebug();
    cclo->printKernelDebug();
    cclo->printKernelProfile();

    print_log(opts.logDir, opts.localRank, format_log(cclo, "all_to_all", opts));

    // polling_and_deserialization(cclo, opts);
}

int main(int argc, char *argv[])  
{

    // ---------------------------------------------------------------
    // Initialization 
    // ---------------------------------------------------------------

    MPI_Init(&argc, &argv);
	
	std::cout << "Reading MPI rank and size values..." << std::endl;
	MPI_Comm_rank(MPI_COMM_WORLD, &mpi_rank);
	MPI_Comm_size(MPI_COMM_WORLD, &mpi_size);

    std::cout << "Getting MPI Processor name..." << std::endl;
	int len;
	char name[MPI_MAX_PROCESSOR_NAME];
	MPI_Get_processor_name(name, &len);

	std::ostringstream stream;
	stream << "rank " << mpi_rank << " size " << mpi_size << " " << name
		   << std::endl;
	std::cout << stream.str();

	MPI_Barrier(MPI_COMM_WORLD);

    // Read arguments
    boost::program_options::options_description programDescription("Options:");
    programDescription.add_options()
                                    ("totalRank,t", boost::program_options::value<uint64_t>(), "Total rank")
                                    ("pkgWordCount,w", boost::program_options::value<uint64_t>(), "Number of 512-bit work in a packet")
                                    ("numMsg,m", boost::program_options::value<uint64_t>(), "Number of messages")
                                    ("payloadSize,s", boost::program_options::value<uint64_t>(), "Message payload to be transferred in Bytes")
                                    ("authLen,a", boost::program_options::value<uint64_t>(), "Authenticator to be transferred in Bytes")
                                    ("fpgaIpStr,f", boost::program_options::value<std::string>()->required(), "fpga ip list string")
                                    ("logDir,d", boost::program_options::value<std::string>(), "directory of log")
                                    ("localRank,l", boost::program_options::value<uint64_t>(), "localRank")
                                    ("rxBatchMaxTimer,r", boost::program_options::value<uint64_t>(), "rxBatchMaxTimer")
                                    ("txBatchNum,b", boost::program_options::value<uint64_t>(), "number of messages in a batch in Tx")
                                    ("offloadMode,o", boost::program_options::value<uint64_t>(), "offload mode")
                                    ("executionMode,x", boost::program_options::value<uint64_t>(), "exe Mode 0: one-to-all; exe Mode 1: all-to-all");
    
    boost::program_options::variables_map commandLineArgs;
    boost::program_options::store(boost::program_options::parse_command_line(argc, argv, programDescription), commandLineArgs);
    boost::program_options::notify(commandLineArgs);

    uint32_t dstIp; 
    uint32_t dstPort;
    uint64_t dstRank;
    uint64_t base_port = 5001;
    std::vector<uint32_t> fpgaIPList;
    uint64_t executionMode = 0;
    
    options_t opts;

    opts.localIp = 0x0AFD4A4C; 
    opts.totalRank = mpi_size;
    opts.pkgWordCount = 64;
    opts.localRank = mpi_rank;
    opts.payloadSize = 1024;
    opts.numMsg = 1;
    opts.authenticatorLen = 0;
    opts.masterRank = 1;
    opts.txBatchNum = 1;
    opts.rxBatchMaxTimer = 0;
    opts.logDir = "./log";
    opts.offloadMode = NET_OFFLOAD;

    // Runtime parameters
    if(commandLineArgs.count("totalRank") > 0) opts.totalRank = commandLineArgs["totalRank"].as<uint64_t>();
    if(commandLineArgs.count("pkgWordCount") > 0) opts.pkgWordCount = commandLineArgs["pkgWordCount"].as<uint64_t>();
    if(commandLineArgs.count("payloadSize") > 0) opts.payloadSize = commandLineArgs["payloadSize"].as<uint64_t>();
    if(commandLineArgs.count("localRank") > 0) opts.localRank = commandLineArgs["localRank"].as<uint64_t>();
    if(commandLineArgs.count("numMsg") > 0) opts.numMsg = commandLineArgs["numMsg"].as<uint64_t>();
    if(commandLineArgs.count("authLen") > 0) opts.authenticatorLen = commandLineArgs["authLen"].as<uint64_t>();
    if(commandLineArgs.count("rxBatchMaxTimer") > 0) opts.rxBatchMaxTimer = commandLineArgs["rxBatchMaxTimer"].as<uint64_t>();
    if(commandLineArgs.count("txBatchNum") > 0) opts.txBatchNum = commandLineArgs["txBatchNum"].as<uint64_t>();
    if(commandLineArgs.count("executionMode") > 0) executionMode = commandLineArgs["executionMode"].as<uint64_t>();
    if(commandLineArgs.count("offloadMode") > 0) opts.offloadMode = commandLineArgs["offloadMode"].as<uint64_t>();

    opts.masterRank = opts.totalRank-1;

    if(commandLineArgs.count("fpgaIpStr") > 0) 
    {
        opts.fpgaIpStr = commandLineArgs["fpgaIpStr"].as<std::string>();
        parse_ip_list_str(opts.fpgaIpStr, fpgaIPList);
        opts.localIp = fpgaIPList[opts.localRank];
    }

    if(commandLineArgs.count("logDir") > 0) 
    {
        opts.logDir = commandLineArgs["logDir"].as<std::string>();
        std::cout<<"Log Dir:"<<opts.logDir<<std::endl;
    }

    printf("total rank: %ld, pkgWordCount: %ld, base_port: %ld, localIp: %x, local rank: %ld, payload size: %ld, auth len: %d, txBatchNum: %ld, rxBatchMaxTimer:%ld\n", opts.totalRank, opts.pkgWordCount, base_port, opts.localIp, opts.localRank, opts.payloadSize, opts.authenticatorLen, opts.txBatchNum, opts.rxBatchMaxTimer);   
    fflush(stdout);

    // CCLO handle
    CCLO cclo;
    
    std::vector<comm_rank> rank_vec;

    for (int i=0; i<opts.totalRank; i++)
    {
        comm_rank rank;
        rank.port = base_port+i;
        rank.ip = fpgaIPList[i];
        rank.session = 0;
        rank_vec.push_back(rank);
    }

    MPI_Barrier(MPI_COMM_WORLD);

    cclo.init_cclo(rank_vec, opts.localRank, opts.totalRank, opts.rxBatchMaxTimer, opts.pkgWordCount);

    // construct bft message
    bft_msg_hdr hdr(opts.offloadMode, 0, opts.localRank, 0, opts.payloadSize, 0, 0, 0, opts.totalRank);
    char* payload = reinterpret_cast<char*>(malloc(opts.payloadSize));
    memset(payload, 1, opts.payloadSize);
    BFT_MSG msg(hdr, payload);

    msg.printHeader();
    msg.printPayload();

    // serialize the bft message
    opts.msgBytes = msg.ByteSize();
    opts.msgBytesR = (opts.msgBytes + 63)/64*64;
    cout<<"msgBytes:"<<dec<<opts.msgBytes<<" msgBytesR:"<<opts.msgBytesR<<endl;
    char * message = reinterpret_cast<char*>(malloc(opts.msgBytesR));
    memset(message,0,opts.msgBytesR);
    msg.SerializeToArray(message);

    // create send buffer
    opts.sendBufSize = opts.msgBytesR * opts.txBatchNum;
    opts.sendBuf = reinterpret_cast<char*>(cclo.getMem(opts.sendBufSize));
    memset(opts.sendBuf,0,opts.sendBufSize);
    for (int i = 0; i< opts.txBatchNum; i++)
    {
        memcpy(opts.sendBuf+opts.msgBytesR*i,message,opts.msgBytesR);
    }

    std::cout<<"checkFPGAWriteToHostCompleted:"<<cclo.checkFPGAWriteToHostCompleted()<<std::endl;

    MPI_Barrier(MPI_COMM_WORLD);

    if (executionMode == 0)
    {
        one_to_all_test(&cclo, opts);
    }
    else if (executionMode == 1)
    {
        all_to_all_test(&cclo, opts);
    } 

    cclo.freeMem(opts.sendBuf);


    std::cout << "Finalizing MPI..." << std::endl;
	MPI_Finalize();
	std::cout << "Done. Terminating..." << std::endl;

    return EXIT_SUCCESS;
}
