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

void communicator(
                hls::stream<ap_uint<64> >& commConfigCmd,
                hls::stream<commLookupReqType >& commLookupReq,
                hls::stream<commLookupRespType >& commLookupResp
                )
{
#pragma HLS INTERFACE axis register  port=commConfigCmd
#pragma HLS INTERFACE axis register  port=commLookupReq
#pragma HLS INTERFACE axis register  port=commLookupResp
#pragma HLS INTERFACE ap_ctrl_none port=return

#pragma HLS aggregate variable=commLookupReq compact=bit
#pragma HLS aggregate variable=commLookupResp compact=bit


#pragma HLS PIPELINE II=1
#pragma HLS INLINE off


static rankTableEntryType rankTable[MAX_NUM_RANK];
#pragma HLS bind_storage variable=rankTable type=RAM_2P impl=LUTRAM
#pragma HLS DEPENDENCE variable=rankTable inter false

    static ap_uint<16> procWord = 0;

    static rankTableEntryType rankTableEntry;

    static ap_uint<16> rankTableAddr;

    static commLookupReqType req;

    enum StateType {IDLE, PARSE_CMD_RANK, INVALIDATE, COMM_RESP};
    static StateType State = IDLE;

    switch (State)
    {
    case IDLE:
        if (!commConfigCmd.empty())
        {
            State = PARSE_CMD_RANK;
        }
        else if (!commLookupReq.empty())
        {
            req = commLookupReq.read();
            rankTableAddr = req.currRank;
            rankTableEntry = rankTable[rankTableAddr];
            State = COMM_RESP;
        }
    break;
    case PARSE_CMD_RANK:
        if (!commConfigCmd.empty())
        {
            
            ap_uint<64> currCmdWord = commConfigCmd.read();
            rankTableEntry.valid = 1;
            rankTableEntry.totalRank = currCmdWord(15,0);
            rankTableEntry.localRank = currCmdWord(31,16);
            rankTableEntry.currRank = currCmdWord(47,32);
            rankTableEntry.session = currCmdWord(63,48);
            rankTableAddr = rankTableEntry.currRank;
            rankTable[rankTableAddr] = rankTableEntry;
            procWord ++;
            if (procWord == rankTableEntry.totalRank)
            {
                if (procWord == MAX_NUM_RANK)
                {
                    procWord = 0;
                    State = IDLE;
                } else {
                    // invalidate old entries
                    State = INVALIDATE;
                }
            }
        }
    break;
    case INVALIDATE:
        rankTableEntry.valid = 0;
        rankTableEntry.totalRank = 0;
        rankTableEntry.localRank = 0;
        rankTableEntry.currRank = 0;
        rankTableEntry.session = 0;
        rankTable[procWord] = rankTableEntry;
        procWord ++;
        if (procWord == MAX_NUM_RANK)
        {
            procWord = 0;
            State = IDLE;

            #ifndef __SYNTHESIS__
            for (size_t i = 0; i < 1; i++)
            {
                std::cout<<"Rank Table "<<i<<std::endl;
                for (size_t j = 0; j < MAX_NUM_RANK; j++)
                {
                    rankTableEntry = rankTable[i*MAX_NUM_RANK+j];
                    if (rankTableEntry.valid)
                    {
                        std::cout<<"Entry: "<<j<<" total rank: "<<rankTableEntry.totalRank<<" local rank: "<<rankTableEntry.localRank<<" currRank: "<<rankTableEntry.currRank<<", session:"<<rankTableEntry.session<<std::endl;
                    } 
                }
            }            
            #endif
        }
    break;
    case COMM_RESP:
        commLookupRespType resp;
        resp.totalRank = rankTableEntry.totalRank;
        resp.currRank = rankTableEntry.currRank;
        resp.localRank = rankTableEntry.localRank;
        resp.session = rankTableEntry.session;
        if (rankTableEntry.valid)
        {
            commLookupResp.write(resp);
        }
        State = IDLE;
    break;
    
    }

}