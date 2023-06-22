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
                hls::stream<pkt512 >& commConfigCmd,
                hls::stream<commLookupReqType >& commLookupReq,
                hls::stream<commLookupRespType >& commLookupResp
                );

int main()
{
    hls::stream<pkt512 > commConfigCmd;
    hls::stream<commLookupReqType > commLookupReq;
    hls::stream<commLookupRespType > commLookupResp;

    ap_uint<32> numComm = 1; // number of communicator
    ap_uint<32> rsvd = 0;
    ap_uint<32> totalRank = 8;
    ap_uint<32> localRank = 1;
    ap_uint<32> ip = 0x01234567;
    ap_uint<32> port = 0x5001;
    ap_uint<32> session = 0;

    pkt512 currConfigWord;

    for (size_t i = 0; i < numComm; i++)
    {
        for (size_t j = 0; j < totalRank; j++)
        {
            currConfigWord.data(31,0) = totalRank;
            currConfigWord.data(63,32) = localRank;
            currConfigWord.data(95,64) = j;
            currConfigWord.data(127,96) = j+ip;
            currConfigWord.data(159,128) = j+port;
            currConfigWord.data(191,160) = j+session;
            currConfigWord.data(223,192) = 0;
            commConfigCmd.write(currConfigWord);
        }
        
    }

    totalRank = 16;
    localRank = 3;

    for (size_t i = 0; i < numComm; i++)
    {
        for (size_t j = 0; j < totalRank; j++)
        {
            currConfigWord.data(31,0) = totalRank;
            currConfigWord.data(63,32) = localRank;
            currConfigWord.data(95,64) = j;
            currConfigWord.data(127,96) = j+ip;
            currConfigWord.data(159,128) = j+port;
            currConfigWord.data(191,160) = j+session;
            currConfigWord.data(223,192) = 0;
            commConfigCmd.write(currConfigWord);
        }
        
    }
    
    int count = 0;
    int sentReq = 0;
    while (count < 1000)
    {

        if (commConfigCmd.empty() & sentReq < totalRank)
        {
            commLookupReqType req;
            req.currRank = sentReq;
            commLookupReq.write(req);
            sentReq ++;
        }
        
        communicator(
                commConfigCmd,
                commLookupReq,
                commLookupResp
                );

        if (!commLookupResp.empty())
        {
            commLookupRespType resp = commLookupResp.read();
            cout<<"commLookupResp: totalRank: "<<resp.totalRank<<" localRank: "<<resp.localRank<<" currRank: "<<resp.currRank<<" session: "<<resp.session<<endl;
        }
        
        count ++;
    }
    

}