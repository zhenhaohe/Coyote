#include "ap_axi_sdata.h"
#include "hls_stream.h"
#include "ap_int.h"

using namespace hls;
using namespace std;

#define MAX_NUM_RANK 16

struct commLookupReqType
{
    ap_uint<32> currRank;
};

struct commLookupRespType
{
    ap_uint<32> totalRank;
    ap_uint<32> localRank;
    ap_uint<32> currRank;
    ap_uint<32> session;
};


struct rankTableEntryType
{
    bool valid;
    ap_uint<32> totalRank;
    ap_uint<32> localRank;
    ap_uint<32> currRank;
    ap_uint<32> ip;
    ap_uint<32> port;
    ap_uint<32> session;
    ap_uint<32> rsvd;
};

