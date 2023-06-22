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

#define MAX_PACKET_BATCH 8
#define MAX_BATCH_SIZE 4096

// This is a batching module to group multiple messages to a large one
// A header is inserted to encode information about the batching
// The first 64-bit stores total payload size and number of messages being batched
// Then the byte size of each message is included in the header with a 8*32 bit array

void tx_cmd_handler(
                hls::stream<ap_uint<64> >& netTxCmd_in,
                hls::stream<ap_uint<512> >& headerInternal,
                hls::stream<ap_uint<64> >& netTxCmd_out,
                ap_uint<64> batchMaxTimer
                )
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    static ap_uint<64> batchByteCnt = 0;
    static ap_uint<64> batchPacketCnt = 0;
    static ap_uint<64> timer = 0;

    static ap_uint<64> cmd;
    static ap_uint<32> cmd_dst;
    static ap_uint<32> cmd_length;

    static ap_uint<32> lengthVec [MAX_PACKET_BATCH];
    #pragma HLS ARRAY_PARTITION variable=lengthVec complete

    enum StateType {INIT, BATCH};
    static StateType State = INIT;
    
    switch(State)
    {
        case INIT:
            if (!netTxCmd_in.empty())
            {
                cmd = netTxCmd_in.read();
                cmd_dst = cmd(31,0);
                cmd_length = ((cmd(63,32) + 63) >> 6) << 6;

                batchByteCnt += cmd_length;
                lengthVec[batchPacketCnt] = cmd_length;
                batchPacketCnt ++;

                if (batchByteCnt >= MAX_BATCH_SIZE | batchPacketCnt == MAX_PACKET_BATCH)
                {
                    ap_uint<64> cmdOut;
                    cmdOut(31,0) = cmd_dst;
                    cmdOut(63,32) = batchByteCnt + 64;
                    netTxCmd_out.write(cmdOut);

                    ap_uint<512> headerWord = 0;
                    headerWord(31,0) = batchByteCnt;
                    headerWord(63,32) = batchPacketCnt;
                    for (int i = 0; i < MAX_PACKET_BATCH; i++)
                    {
                        #pragma HLS UNROLL
                        headerWord(64+i*32+31, 64+i*32) = lengthVec[i];
                        lengthVec[i] = 0;
                    }
                    headerInternal.write(headerWord);

                    batchByteCnt = 0;
                    batchPacketCnt = 0;
                } else {
                    State = BATCH;
                }
            }
            
        break;
        case BATCH:
            timer++;
            if (timer >= batchMaxTimer)
            {
                ap_uint<64> cmdOut;
                cmdOut(31,0) = cmd_dst;
                cmdOut(63,32) = batchByteCnt + 64;
                netTxCmd_out.write(cmdOut);

                ap_uint<512> headerWord = 0;
                headerWord(31,0) = batchByteCnt;
                headerWord(63,32) = batchPacketCnt;
                for (int i = 0; i < MAX_PACKET_BATCH; i++)
                {
                    #pragma HLS UNROLL
                    headerWord(64+i*32+31, 64+i*32) = lengthVec[i];
                    lengthVec[i] = 0;
                }
                headerInternal.write(headerWord);

                timer = 0;
                batchByteCnt = 0;
                batchPacketCnt = 0;
                State = INIT;
            } else if (!netTxCmd_in.empty())
            {
                cmd = netTxCmd_in.read();
                cmd_dst = cmd(31,0);
                cmd_length = ((cmd(63,32) + 63) >> 6) << 6;

                batchByteCnt += cmd_length;
                lengthVec[batchPacketCnt] = cmd_length;
                batchPacketCnt ++;

                if (batchByteCnt >= MAX_BATCH_SIZE | batchPacketCnt == MAX_PACKET_BATCH)
                {
                    ap_uint<64> cmdOut;
                    cmdOut(31,0) = cmd_dst;
                    cmdOut(63,32) = batchByteCnt + 64;
                    netTxCmd_out.write(cmdOut);

                    ap_uint<512> headerWord = 0;
                    headerWord(31,0) = batchByteCnt;
                    headerWord(63,32) = batchPacketCnt;
                    for (int i = 0; i < MAX_PACKET_BATCH; i++)
                    {
                        #pragma HLS UNROLL
                        headerWord(64+i*32+31, 64+i*32) = lengthVec[i];
                        lengthVec[i] = 0;
                    }
                    headerInternal.write(headerWord);

                    timer = 0;
                    batchByteCnt = 0;
                    batchPacketCnt = 0;
                    State = INIT;
                }
            }
        break;
    }
    
}

void tx_data_handler(
                hls::stream<pkt512 >& netTxData_in,
                hls::stream<ap_uint<512> >& headerInternal,
                hls::stream<pkt512 >& netTxData_out
                )
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    enum StateType {HEADER, PAYLOAD};
    static StateType State = HEADER;

    static ap_uint<512> header;
    static ap_uint<32> payload_length;
    static ap_uint<32> payload_packet;

    static ap_uint<32> payload_word;
    static ap_uint<32> word_cnt = 0;
    switch(State)
    {
        case HEADER:
            if (!headerInternal.empty())
            {
                header = headerInternal.read();
                payload_length = header(31,0);
                payload_packet = header(63,32);
                payload_word = (payload_length + 63) >> 6;

                pkt512 outWord;
                outWord.data = header;
                outWord.keep = 0xFFFFFFFFFFFFFFFF;
                outWord.last = 0;
                netTxData_out.write(outWord);

                State = PAYLOAD;
            }
        break;
        case PAYLOAD:
            if (!netTxData_in.empty())
            {
                pkt512 currWord = netTxData_in.read();
                word_cnt ++;
                
                pkt512 outWord;
                outWord.data = currWord.data;
                outWord.keep = 0xFFFFFFFFFFFFFFFF;
                outWord.last = (word_cnt == payload_word);
            
                netTxData_out.write(outWord);

                if (outWord.last)
                {
                    word_cnt = 0;
                    State = HEADER;
                }
            }
        break;
    }
    
}

void host_packetBatcher(
    hls::stream<ap_uint<64> >& netTxCmd_in,
    hls::stream<pkt512 >& netTxData_in,
    hls::stream<ap_uint<64> >& netTxCmd_out,
    hls::stream<pkt512 >& netTxData_out,
    ap_uint<64> batchMaxTimer
)
{
#pragma HLS INTERFACE axis register  port=netTxCmd_in
#pragma HLS INTERFACE axis register  port=netTxData_in
#pragma HLS INTERFACE axis register  port=netTxCmd_out
#pragma HLS INTERFACE axis register  port=netTxData_out
#if defined( __VITIS_HLS__)
    #pragma HLS INTERFACE ap_none register port=batchMaxTimer
#else
    #pragma HLS INTERFACE ap_stable register port=batchMaxTimer
#endif
#pragma HLS INTERFACE ap_ctrl_none port=return

#pragma HLS DATAFLOW disable_start_propagation

    static hls::stream<ap_uint<512> > headerInternal;
    #pragma HLS stream variable=headerInternal depth=16

    tx_cmd_handler(
                netTxCmd_in,
                headerInternal,
                netTxCmd_out,
                batchMaxTimer
                );

    tx_data_handler(
                netTxData_in,
                headerInternal,
                netTxData_out
                );

}
