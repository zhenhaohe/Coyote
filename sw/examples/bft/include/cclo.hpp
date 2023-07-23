#pragma once

#include <cstdint>
#include "cDefs.hpp"
#include "cProcess.hpp"
#include "common.hpp"
#include "buf.hpp"
#include <vector>

using namespace fpga;
// -------------------------------------------------------------------------------
// collective management
// -------------------------------------------------------------------------------
typedef struct {
	uint32_t ip;
	uint32_t port;
  	uint32_t session;
} comm_rank;

typedef struct {
	uint32_t size;
	uint32_t localRank;
	std::vector<comm_rank> rank_vec;
} communicator;

struct rcv_meta_t
{
    bool new_transfer;
	unsigned int num_rcv_msg;
	unsigned int num_rcv_bytes;

    // Constructor
    rcv_meta_t() : new_transfer(false), num_rcv_msg(0), num_rcv_bytes(0) {}
};

class CCLO {
private:

	communicator comm;
	fpga::cProcess cproc;

	rxHandler_t rxHandler;
	// txHandler_t txHanlder;

	bool Verbose;
	bool Terminate;

	debug_type sts_cnt;

public: 
	
	CCLO() : cproc(0, getpid()), Terminate(false), Verbose(false) {}
	~CCLO(){};

	// initialize cclo
	void init_cclo(std::vector<comm_rank> rank_vec, unsigned int local_rank, unsigned int total_rank, uint64_t rxBatchMaxTimer, uint64_t pkgWordCount);

	// communicator
	void open_port (unsigned int port);

	bool open_connection (unsigned int ip, unsigned int port, unsigned int rank);

	void offload_communicator();

	// buffer management
	// void create_sendBuf (unsigned int bytes);

	void create_recvBuf (unsigned int bytes);

	void enqueue_recvBuf_hw (buf_t curr_buf);

	rcv_meta_t receive(void* user_buf, unsigned int user_buf_size);

	// Mem
	inline void* getMem(unsigned int bytes)  {
		uint32_t numPage = (uint32_t)bytes/hugePageSize + (((uint32_t)bytes%hugePageSize > 0)? 1 : 0); 
		printf("getMem numPage: %d\n", numPage);
		fflush(stdout);
		return cproc.getMem({CoyoteAlloc::HUGE_2M, numPage}); 
	};

	inline void freeMem(void *vaddr)  { 
		cproc.freeMem(vaddr); 
	};

	// CSR
	inline void setCSR(unsigned long long val, unsigned long long offs)  { 
		cproc.setCSR((uint64_t)val, (uint32_t)offs); 
	}
	
	inline uint64_t getCSR(unsigned int offs)  {  
		return cproc.getCSR((uint32_t)offs); 
	};

	// Bulk
	inline void invokeHostWriteToFPGA(void*addr, unsigned int len) {
		cproc.invoke({CoyoteOper::READ, addr, (uint32_t)len, false, false, 0, true});
	}

	inline void invokeFPGAWriteToHost(void*addr, unsigned int len) {
		cproc.invoke({CoyoteOper::WRITE, addr, len, false, false, 0, true});
	}

	// Status
	inline unsigned int checkHostWriteToFPGACompleted()  { 
		return ((unsigned int)cproc.checkCompleted(CoyoteOper::READ)); 
	}

	inline unsigned int checkFPGAWriteToHostCompleted()  { 
		return ((unsigned int)cproc.checkCompleted(CoyoteOper::WRITE)); 
	}

	inline void clearCompleted()  { 
		cproc.clearCompleted(); 
	}

	bool probeDone () { 
		return (cproc.getCSR(OFFSET_BFT_CRTL+BFT_CRTL::STATUS) == 1);
	}

	void startKernel () {
		cproc.setCSR(1, OFFSET_BFT_CRTL+BFT_CRTL::CONTROL);
	}

	// set flags
	void setTerminate() { 
		Terminate = true;
	}

	void setVerbose () {
		Verbose = true;
	}

	void setClear() {
		cproc.setCSR(1, OFFSET_INTF_CTRL+INTF_CTRL::CONTROL);
		cproc.setCSR(1, OFFSET_BFT_CRTL+BFT_CRTL::CONTROL);
	}


	// debug counters

	void getDebugCounters();
	
	void printKernelDebug();
	
	void printKernelProfile();

	inline void printDebug() {
		cproc.printDebug(); 
	}

	std::string format_log(std::string exp, unsigned int totalRank, unsigned int localRank, unsigned int pkgWordCount, unsigned int payloadSize, unsigned int numMsg, unsigned int authenticatorLen, unsigned int txBatchNum, unsigned int rxBatchMaxTimer, unsigned int parallel_threads);

};

