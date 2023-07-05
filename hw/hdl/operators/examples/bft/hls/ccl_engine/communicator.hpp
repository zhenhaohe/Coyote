#include "ap_axi_sdata.h"
#include "hls_stream.h"
#include "ap_int.h"

using namespace hls;
using namespace std;

#define MAX_NUM_RANK 16

struct commLookupReqType
{
    ap_uint<16> currRank;
};

struct commLookupRespType
{
    ap_uint<16> totalRank;
    ap_uint<16> localRank;
    ap_uint<16> currRank;
    ap_uint<16> session;
};


struct rankTableEntryType
{
    bool valid;
    ap_uint<16> totalRank;
    ap_uint<16> localRank;
    ap_uint<16> currRank;
    ap_uint<16> session;
};

