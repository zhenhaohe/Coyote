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

#define BUFFER_DEPTH 8192
#define MAX_QUEUE 64

struct wrStatusReqType
{
	ap_uint<32>	byteLen;
};

struct wrStatusRespType
{
	ap_uint<16>	addr;
    ap_uint<16> queueIndex;
    ap_uint<32> byteLen;
    ap_uint<1> success;
};

struct rdStatusUpdType
{
	ap_uint<16>	addr;
    ap_uint<16> queueIndex;
    ap_uint<32> byteLen;
};

void msg_buffer_handler (
                    hls::stream<ap_uint<16> >& rdAddr,
                    hls::stream<pkt512 >& rdStream,
                    hls::stream<ap_uint<16> >& wrAddr,
					hls::stream<pkt512 >& wrStream)
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    static pkt512 msg_buffer[BUFFER_DEPTH];
	#pragma HLS RESOURCE variable=msg_buffer core=RAM_T2P_URAM

	if (!wrAddr.empty())
	{
		ap_uint<16> wrAddr = wrAddr.read();
        pkt512 wrWord = wrStream.read();
		msg_buffer[wrAddr] = wrWord;
	}

    if (!rdAddr.empty())
    {
        ap_uint<16> rdAddr = rdAddr.read();
        pkt512 rdWord = msg_buffer[rdAddr];
        rdStream.write(rdWord);
    }
    
}

// everytime receives a wrMeta, asks the status table for the avalability of next queue
// status returns success flag, address and queue index
// if success, write the meta out, otherwise, re-send the request
void wr_fsm_meta_handler(
        hls::stream<ap_uint<32> >& wrStreamLenIn,
        hls::stream<wrStatusReqType >& wrStatusReqOut,
        hls::stream<wrStatusRespType >& wrStatusRespIn,
        hls::stream<wrStatusRespType >& wrMetaInternal
    )
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    enum fsmStateType {WAIT_META, RESP, REQ_AGAIN};
    static fsmStateType  fsmState = WAIT_META;

    static ap_uint<32> byteLen;
    static ap_uint<8> wait_cnt = 0;

    switch (fsmState)
    {
    case WAIT_META:
        if (!wrStreamLenIn.empty())
        {
            byteLen = wrStreamLenIn.read();
            wrStatusReqType wrReq;
            wrReq.byteLen = byteLen;
            wrStatusReqOut.write(wrReq);
            fsmState = RESP;
        }
    break;
    case RESP:
        if (!wrStatusRespIn.empty())
        {
            wrStatusRespType wrResp = wrStatusRespIn.read();
            if (wrResp.success == 1)
            {
                wrMetaInternal.write(wrResp);
                fsmState = WAIT_META;
            }
            else {
                fsmState = REQ_AGAIN;
            }
        }
    break;
    case REQ_AGAIN:
        wait_cnt ++;
        if (wait_cnt == 3)
        {
            wrStatusReqType wrReq;
            wrReq.byteLen = byteLen;
            wrStatusReqOut.write(wrReq);
            wait_cnt = 0;
            fsmState = WAIT_META;
        }
    break;
    }
}

void wr_fsm_stream_handler(
        hls::stream<pkt512 >& wrStreamIn,
        hls::stream<wrStatusRespType >& wrMetaInternal,

        hls::stream<ap_uint<64> >& shaMetaOut,
        hls::stream<pkt512 >& shaStreamOut,

        hls::stream<ap_uint<16> >& wrAddrOut,
        hls::stream<pkt512 >& wrStreamOut,
        hls::stream<wrStatusRespType >& wrDoneOut
)
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    enum fsmStateType {WAIT_META, WR_STREAM};
    static fsmStateType  fsmState = WAIT_META;

    static ap_uint<32> offset = 0;
    static ap_uint<32> numWr;

    switch (fsmState)
    {
    case WAIT_META:
        if (!wrMetaInternal.empty())
        {
            wrStatusRespType wrMeta = wrMetaInternal.read();
            numWr = (wrMeta.byteLen + 63) >> 6;
            ap_uint<64> shaMeta;
            shaMeta(31,0) = wrMeta.ByteLen;
            shaMeta(47,32) = wrMeta.queueIndex;
            shaMeta(63,48) = wrMeta.addr;
            shaMetaOut.write(shaMeta);
            fsmState = WR_STREAM;
        }
    break;
    case WR_STREAM:
        pkt512 currWord = wrStreamIn.read();
        wrStreamOut.write(currWord);
        shaStreamOut.write(currWord);
        ap_uint<32> currAddr = wrMeta.addr + offset;
        wrAddrOut.write(currAddr);
        offset ++;
        if (offset == numWr)
        {
            wrDoneOut.write(wrMeta);
            offset = 0;
            fsmState = WAIT_META;
        }
        
    break;
    }
}

void rd_fsm_handler(
                hls::stream<ap_uint<64> >& rdMetaIn,
                hls::stream<ap_uint<16> >& rdAddr,
                hls::stream<rdStatusUpdType >& rdDoneOut
)
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    enum fsmStateType {WAIT_META, RD_STREAM};
    static fsmStateType  fsmState = WAIT_META;

    static ap_uint<64> rdMeta;
    static ap_uint<32> offset = 0;
    static ap_uint<32> numRd;
    static ap_uint<16> addr;
    static ap_uint<16> queueIndex;
    static ap_uint<32> byteLen;

    switch (fsmState)
    {
    case WAIT_META:
        if (!rdMetaIn.empty())
        {
            rdMeta = rdMetaIn.read();
            byteLen = rdMeta(31,0);
            queueIndex = rdMeta(47,32);
            addr = rdMeta(63,48);
            numRd = (byteLen + 63) >> 6;
            fsmState = RD_STREAM;
        }
    break;
    case RD_STREAM:
        ap_uint<32> currAddr = addr + offset;
        rdAddr.write(currAddr);
        offset ++;
        if (offset == numRd)
        {
            rdStatusUpdType rdDone;
            rdDone.addr = addr;
            rdDone.queueIndex = queueIndex;
            rdDone.byteLen = byteLen;
            rdDoneOut.write(rdDone);
            offset = 0;
            fsmState = WAIT_META;
        }
        
    break;
    }

}


void status_table_handler(
                hls::stream<wrStatusReqType >& wrStatusReqIn,
                hls::stream<wrStatusRespType >& wrStatusRespOut,
                hls::stream<wrStatusRespType >& wrDoneIn,
                hls::stream<rdStatusUpdType >& rdDoneIn
)
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    static ap_uint<16> wr_pointer [MAX_QUEUE];
    #pragma HLS ARRAY_PARTITION variable=wr_pointer complete
    static ap_uint<16> rd_pointer [MAX_QUEUE];
    #pragma HLS ARRAY_PARTITION variable=rd_pointer complete


    if (!wrDoneIn.empty())
    {
        wrStatusRespType wrDone = wrDoneIn.read();
        wr_pointer[wrDone.queueIndex] = wr_pointer[wrDone.queueIndex] + (wrDone.byteLen + 63) >> 6;
    }

    if (!rdDoneIn.empty())
    {
        rdStatusUpdType rdDone = rdDoneIn.read();
        rd_pointer[rdDone.queueIndex] = rd_pointer[rdDone.queueIndex] + (rdDone.byteLen + 63) >> 6;
    }
    
    

}

void bft_aes_sha_msg_buffer_handler(
                hls::stream<pkt512 >& strmIn,
                hls::stream<pkt512 >& authOut,
                hls::stream<pkt512 >& strmOut,
                hls::stream<pkt512 >& hashOut
                )
{
#pragma HLS INTERFACE axis register  port=strmIn
#pragma HLS INTERFACE axis register  port=strmOut
#pragma HLS INTERFACE axis register  port=authOut
#pragma HLS INTERFACE axis register  port=hashOut
#pragma HLS INTERFACE ap_ctrl_none port=return

#pragma HLS DATAFLOW disable_start_propagation

    static hls::stream<pkt512 > strmOutBuf;
    #pragma HLS stream variable=strmOutBuf depth=8
    #pragma HLS RESOURCE variable=strmOutBuf core=FIFO_LUTRAM
    // #pragma HLS bind_storage variable=strmOutBuf type=fifo impl=lutram

    static hls::stream<pkt512 > hashOutBuf;
    #pragma HLS stream variable=hashOutBuf depth=8
    #pragma HLS RESOURCE variable=hashOutBuf core=FIFO_LUTRAM
    // #pragma HLS bind_storage variable=hashOutBuf type=fifo impl=lutram

    static hls::stream<pkt512 > authOutBuf;
    #pragma HLS stream variable=authOutBuf depth=8
    #pragma HLS RESOURCE variable=authOutBuf core=FIFO_LUTRAM
    // #pragma HLS bind_storage variable=authOutBuf type=fifo impl=lutram

    bft_aes_sha_msg_buffer_handler_splitter(
                strmIn,
                authOutBuf,
                strmOutBuf,
                hashOutBuf
                );

    streamBuffer (
                authOutBuf,
				authOut);

    streamBuffer (
                strmOutBuf,
				strmOut);

    streamBuffer (
                hashOutBuf,
				hashOut);

}
