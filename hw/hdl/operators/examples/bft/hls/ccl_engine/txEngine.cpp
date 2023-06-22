/*
 * Copyright (c) 2021, Systems Group, ETH Zurich
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without modification,
 * are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 * 3. Neither the name of the copyright holder nor the names of its contributors
 * may be used to endorse or promote products derived from this software
 * without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#include "ap_axi_sdata.h"
#include "hls_stream.h"
#include "ap_int.h"
#include "communicator.hpp"

using namespace hls;
using namespace std;


#define DWIDTH512 512
#define DWIDTH256 256
#define DWIDTH128 128
#define DWIDTH64 64
#define DWIDTH32 32
#define DWIDTH16 16
#define DWIDTH8 8


typedef ap_axiu<DWIDTH512, 0, 0, 0> pkt512;
typedef ap_axiu<DWIDTH256, 0, 0, 0> pkt256;
typedef ap_axiu<DWIDTH128, 0, 0, 0> pkt128;
typedef ap_axiu<DWIDTH64, 0, 0, 0> pkt64;
typedef ap_axiu<DWIDTH32, 0, 0, 0> pkt32;
typedef ap_axiu<DWIDTH16, 0, 0, 0> pkt16;
typedef ap_axiu<DWIDTH8, 0, 0, 0> pkt8;

void tx_cmd_handler(
                hls::stream<ap_uint<64> >& netTxCmd_in,
                hls::stream<commLookupReqType >& commLookupReq,
                hls::stream<ap_uint<64> >& txMetaInternal
                )
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    static commLookupReqType comLookupReq;
    static ap_uint<64> cmd;
    static ap_uint<32> cmd_rank;
    static ap_uint<32> cmd_length;

    if (!netTxCmd_in.empty())
    {
        cmd = netTxCmd_in.read();
        cmd_rank = cmd(31,0);
        cmd_length = cmd(63,32);
        comLookupReq.currRank = cmd_rank;
        commLookupReq.write(comLookupReq);
        txMetaInternal.write(cmd);
    }
    
}

void tx_data_handler(
                hls::stream<pkt512 >& netTxData_in,
                hls::stream<ap_uint<64> >& txMetaInternal,
                hls::stream<commLookupRespType >& commLookupResp,
                hls::stream<ap_uint<64> >& netTxCmd_out,
                hls::stream<pkt512 >& netTxData_out
                )
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    enum StateType {LOOKUP_RESP_AND_HEADER, PAYLOAD};
    static StateType State = LOOKUP_RESP_AND_HEADER;

    static commLookupRespType lookupResp;
    static ap_uint<64> meta;
    static ap_uint<32> meta_rank;
    static ap_uint<32> meta_length;
    static ap_uint<64> cmd;
    static ap_uint<32> cmd_session;
    static ap_uint<32> cmd_length;

    switch(State)
    {
        case LOOKUP_RESP_AND_HEADER:
            if (!txMetaInternal.empty() & !commLookupResp.empty())
            {
                meta = txMetaInternal.read();
                meta_rank = meta(31,0);
                meta_length = meta(63,32);
                lookupResp = commLookupResp.read();
                cmd_session = lookupResp.session;
                cmd_length = ((meta_length + 63) >> 6) << 6;
                cmd(31,0) = cmd_session;
                cmd(63,32) = cmd_length;
                netTxCmd_out.write(cmd);

                State = PAYLOAD;
            }
        break;
        case PAYLOAD:
            if (!netTxData_in.empty())
            {
                pkt512 currWord = netTxData_in.read();
                pkt512 outWord;
                outWord.data = currWord.data;
                outWord.keep = 0xFFFFFFFFFFFFFFFF;
                outWord.last = currWord.last;
                netTxData_out.write(outWord);
                if (currWord.last)
                {
                    State = LOOKUP_RESP_AND_HEADER;
                }
            }
        break;
    }
    
}

void txEngine(
    hls::stream<ap_uint<64> >& netTxCmd_in,
    hls::stream<pkt512 >& netTxData_in,
    hls::stream<ap_uint<64> >& netTxCmd_out,
    hls::stream<pkt512 >& netTxData_out,
    hls::stream<commLookupReqType >& commLookupReq,
    hls::stream<commLookupRespType >& commLookupResp
)
{
#pragma HLS INTERFACE axis register  port=netTxCmd_in
#pragma HLS INTERFACE axis register  port=netTxData_in
#pragma HLS INTERFACE axis register  port=netTxCmd_out
#pragma HLS INTERFACE axis register  port=netTxData_out
#pragma HLS INTERFACE axis register  port=commLookupReq
#pragma HLS INTERFACE axis register  port=commLookupResp
#pragma HLS INTERFACE ap_ctrl_none port=return

#pragma HLS aggregate variable=commLookupReq compact=bit
#pragma HLS aggregate variable=commLookupResp compact=bit


#pragma HLS DATAFLOW disable_start_propagation

    static hls::stream<ap_uint<64> > txMetaInternal;
    #pragma HLS stream variable=txMetaInternal depth=16

    tx_cmd_handler(
                netTxCmd_in,
                commLookupReq,
                txMetaInternal
                );

    
    tx_data_handler(
                netTxData_in,
                txMetaInternal,
                commLookupResp,
                netTxCmd_out,
                netTxData_out
                );

}
