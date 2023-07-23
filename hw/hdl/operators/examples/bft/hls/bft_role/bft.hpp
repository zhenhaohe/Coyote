#include "ap_axi_sdata.h"
#include "hls_stream.h"
#include "ap_int.h"

using namespace hls;
using namespace std;

// used in communicator and auth key handler
#define MAX_NUM_RANK 16

// Used in bft_bcast
// This means the largest bcast length
#define BCAST_BUF_DEPTH 1024 //1024 * 64 bytes -> 64 KB

#define NET_OFFLOAD 0
#define AUTH_OFFLOAD 1


#define HEADER_TYPE_CMDID_START         0
#define HEADER_TYPE_CMDID_END           31
#define HEADER_TYPE_CMDLEN_START        HEADER_TYPE_CMDID_END + 1
#define HEADER_TYPE_CMDLEN_END          HEADER_TYPE_CMDLEN_START + 31
#define HEADER_TYPE_DST_START           HEADER_TYPE_CMDLEN_END + 1
#define HEADER_TYPE_DST_END             HEADER_TYPE_DST_START + 31
#define HEADER_TYPE_SRC_START           HEADER_TYPE_DST_END + 1
#define HEADER_TYPE_SRC_END             HEADER_TYPE_SRC_START + 31
#define HEADER_TYPE_TAG_START           HEADER_TYPE_SRC_END + 1
#define HEADER_TYPE_TAG_END             HEADER_TYPE_TAG_START + 31
#define HEADER_TYPE_DATALEN_START       HEADER_TYPE_TAG_END + 1
#define HEADER_TYPE_DATALEN_END         HEADER_TYPE_DATALEN_START + 31
#define HEADER_TYPE_MSGID_START         HEADER_TYPE_DATALEN_END + 1
#define HEADER_TYPE_MSGID_END           HEADER_TYPE_MSGID_START + 31
#define HEADER_TYPE_MSGTYPE_START       HEADER_TYPE_MSGID_END + 1
#define HEADER_TYPE_MSGTYPE_END         HEADER_TYPE_MSGTYPE_START + 31
#define HEADER_TYPE_EPOCHID_START       HEADER_TYPE_MSGTYPE_END + 1
#define HEADER_TYPE_EPOCHID_END         HEADER_TYPE_EPOCHID_START + 31
#define HEADER_TYPE_TOTALRANK_START     HEADER_TYPE_EPOCHID_END + 1
#define HEADER_TYPE_TOTALRANK_END       HEADER_TYPE_TOTALRANK_START + 31
#define HEADER_LENGTH                   HEADER_TYPE_TOTALRANK_END+1

struct headerType {
    ap_uint<32> cmdID;
    ap_uint<32> cmdLen;
    ap_uint<32> dst;
    ap_uint<32> src;
    ap_uint<32> tag;
    ap_uint<32> dataLen;
    ap_uint<32> msgID;
    ap_uint<32> msgType;
    ap_uint<32> epochID;
    ap_uint<32> totalRank;

    headerType()
        : cmdID(0), cmdLen(0), dst(0), src(0), tag(0),
          dataLen(0), msgID(0), msgType(0), epochID(0), totalRank(0) {}

    headerType(ap_uint<HEADER_LENGTH> in)
        : cmdID(in(HEADER_TYPE_CMDID_END, HEADER_TYPE_CMDID_START)),
          cmdLen(in(HEADER_TYPE_CMDLEN_END, HEADER_TYPE_CMDLEN_START)),
          dst(in(HEADER_TYPE_DST_END, HEADER_TYPE_DST_START)),
          src(in(HEADER_TYPE_SRC_END, HEADER_TYPE_SRC_START)),
          tag(in(HEADER_TYPE_TAG_END, HEADER_TYPE_TAG_START)),
          dataLen(in(HEADER_TYPE_DATALEN_END, HEADER_TYPE_DATALEN_START)),
          msgID(in(HEADER_TYPE_MSGID_END, HEADER_TYPE_MSGID_START)),
          msgType(in(HEADER_TYPE_MSGTYPE_END, HEADER_TYPE_MSGTYPE_START)),
          epochID(in(HEADER_TYPE_EPOCHID_END, HEADER_TYPE_EPOCHID_START)),
          totalRank(in(HEADER_TYPE_TOTALRANK_END, HEADER_TYPE_TOTALRANK_START)) {}

    operator ap_uint<HEADER_LENGTH>() {
        ap_uint<HEADER_LENGTH> ret;
        ret(HEADER_TYPE_CMDID_END, HEADER_TYPE_CMDID_START) = cmdID;
        ret(HEADER_TYPE_CMDLEN_END, HEADER_TYPE_CMDLEN_START) = cmdLen;
        ret(HEADER_TYPE_DST_END, HEADER_TYPE_DST_START) = dst;
        ret(HEADER_TYPE_SRC_END, HEADER_TYPE_SRC_START) = src;
        ret(HEADER_TYPE_TAG_END, HEADER_TYPE_TAG_START) = tag;
        ret(HEADER_TYPE_DATALEN_END, HEADER_TYPE_DATALEN_START) = dataLen;
        ret(HEADER_TYPE_MSGID_END, HEADER_TYPE_MSGID_START) = msgID;
        ret(HEADER_TYPE_MSGTYPE_END, HEADER_TYPE_MSGTYPE_START) = msgType;
        ret(HEADER_TYPE_EPOCHID_END, HEADER_TYPE_EPOCHID_START) = epochID;
        ret(HEADER_TYPE_TOTALRANK_END, HEADER_TYPE_TOTALRANK_START) = totalRank;
        return ret;
    }
};
