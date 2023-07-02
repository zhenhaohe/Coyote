#include "ap_axi_sdata.h"
#include "hls_stream.h"
#include "ap_int.h"

using namespace hls;
using namespace std;

#define MAX_NUM_RANK 16

// This means the largest bcast length
#define BCAST_BUF_DEPTH 1024 //1024 * 64 bytes -> 64 KB

#define NET_OFFLOAD 0
#define AUTH_OFFLOAD 1

struct headerType
{
    ap_uint<32> cmdID; // specifier of different communication primitive
    ap_uint<32> cmdLen; // total byte len of compulsory & optional cmd fields
    ap_uint<32> dst; // either dst rank or communicator ID depends on primitive
    ap_uint<32> src; // src rank
    ap_uint<32> tag; // tag, reserved
    ap_uint<32> dataLen; //total byte len of data to each primitive
    ap_uint<32> msgID;
    ap_uint<32> msgType;
    ap_uint<32> epochID;
    ap_uint<32> totalRank;
};

