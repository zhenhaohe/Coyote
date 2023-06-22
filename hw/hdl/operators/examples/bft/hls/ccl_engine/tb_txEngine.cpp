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

int ntransfers(int nbytes){
	int bytes_per_transfer = 512/8;
	return (nbytes+bytes_per_transfer-1)/bytes_per_transfer;
}

void txEngine(
    hls::stream<ap_uint<64> >& netTxCmd_in,
    hls::stream<pkt512 >& netTxData_in,
    hls::stream<ap_uint<64> >& netTxCmd_out,
    hls::stream<pkt512 >& netTxData_out,
    hls::stream<commLookupReqType >& commLookupReq,
    hls::stream<commLookupRespType >& commLookupResp
);

int main()
{
    hls::stream<pkt512 > netTxData_in;
    hls::stream<pkt512 > netTxData_out;
    hls::stream<ap_uint<64> > netTxCmd_in;
    hls::stream<ap_uint<64> > netTxCmd_out;
    hls::stream<commLookupReqType > commLookupReq;
    hls::stream<commLookupRespType > commLookupResp;
    hls::stream<pkt512 > golden;

    int totalRank = 16;
    int localRank = 0;
    int numMsg = 512;
    int msgSize = 1024;

    pkt512 currCmdWord;

    printf("numMsg:%d, msgSize:%d, totalRank:%d, localRank:%d\n", (int)numMsg, (int)msgSize, totalRank, localRank);

    // pack 
    ap_uint<64> cmd_in;
    for (size_t j = 0; j < numMsg; j++)
    {
        cmd_in(31,0) = j % totalRank; //rank
        cmd_in(63,32) = msgSize; //length
        netTxCmd_in.write(cmd_in);
        // cout<<"netTxCmd_in rank:"<<(int)cmd_in(31,0)<<" length:"<<cmd_in(63,32)<<endl;
        // pack payload
        for (size_t i = 0; i < ntransfers(msgSize); i++)
        {
            currCmdWord.data = j;
            currCmdWord.keep = 0xFFFFFFFFFFFFFFFF;
            currCmdWord.last = (i == ntransfers(msgSize)-1);
            netTxData_in.write(currCmdWord);
            // cout<<"netTxData_in "<<std::hex<<currCmdWord.data<<" last "<<currCmdWord.last<<endl;
            golden.write(currCmdWord);
        }
    }
    

    printf("Finished packing\n");
    

    int count = 0;
    pkt512 outword;
    pkt512 goldenword;
    ap_uint<64> netCmd;
    bool sendResp = false;
    ap_uint<32> resp_count = 0;
    ap_uint<32> outwordCnt = 0;
    bool isFirstOutWord = true;
    ap_uint<32> currRank = 0;

    while(count < 10000)
    {

    	txEngine(
            netTxCmd_in,
            netTxData_in,
            netTxCmd_out,
            netTxData_out,
            commLookupReq,
            commLookupResp
            );


        if (!commLookupReq.empty())
        {
            currRank = commLookupReq.read().currRank;
            // cout<<"commLookupReq currRank"<<std::hex<<currRank<<endl;
            sendResp = true;
        }

        if (sendResp)
        {
            commLookupRespType resp;
            resp.totalRank = totalRank;
            resp.currRank = currRank;
            resp.session = currRank;
            resp.localRank = localRank;
            commLookupResp.write(resp);
            sendResp = false;
        }
        
        if (!netTxCmd_out.empty())
    	{
    		netCmd = netTxCmd_out.read();
			// cout<<"netTxCmd_out session"<<std::hex<<netCmd(31,0)<<" length "<<netCmd(63,32)<<endl;
    	}


    	if (!netTxData_out.empty())
    	{
            outword = netTxData_out.read();
            if(isFirstOutWord)
            {
                // cout<<"netTxData_out Header "<<std::hex<<outword.data<<" last "<<outword.last<<endl;
                isFirstOutWord = false;
            }  
            else 
            {
                goldenword = golden.read();
                // cout<<"netTxData_out "<<std::hex<<outword.data<<" last "<<outword.last<<" golden data "<<goldenword.data<<" last "<<goldenword.last<<endl;
                outwordCnt++;
                if(outword.data != goldenword.data | outword.last != goldenword.last) 
                {   
                    cout<<"Word Index:"<<outwordCnt<<"netTxData_out "<<std::hex<<outword.data<<" last "<<outword.last<<" golden data "<<goldenword.data<<" last "<<goldenword.last<<endl;
                    return 1;
                }
                
            }

            if(outword.last)
                isFirstOutWord = true;
            
    	}


    	count++;
    }


	
	return 0;
    



}