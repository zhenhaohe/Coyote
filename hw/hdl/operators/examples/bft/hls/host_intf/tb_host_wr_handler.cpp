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
#include "host_pkg.hpp"

using namespace hls;
using namespace std;

#define DWIDTH512 512
#define DWIDTH256 256
#define DWIDTH128 128
#define DWIDTH64 64
#define DWIDTH32 32
#define DWIDTH16 16
#define DWIDTH8 8

#define DATA_WIDTH 512

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

void host_wr_handler(
               hls::stream<pkt512 >& host_wr_data,
               hls::stream<ap_uint<94> >& host_wr_req,
               hls::stream<pkt512>& wr_data, 
               hls::stream<ap_uint<64> >& wr_meta,
               ap_uint<64> base_addr,
               ap_uint<64> buff_size,
               ap_uint<1> ap_start_pulse
                );

int main()
{
	hls::stream<pkt512 > host_wr_data;
    hls::stream<ap_uint<94> > host_wr_req;
    hls::stream<pkt512> wr_data;
    hls::stream<ap_uint<64> > wr_meta;
    ap_uint<64> base_addr;
    ap_uint<64> buff_size;
    ap_uint<1> ap_start_pulse;

    stream<ap_axiu<DATA_WIDTH,0,0,0> > golden;

    ap_axiu<DATA_WIDTH,0,0,0> inword;
	ap_axiu<DATA_WIDTH,0,0,0> outword;
	ap_axiu<DATA_WIDTH,0,0,0> goldenword;

    int count;
    ap_uint<16> session;
    ap_uint<16> pkt_size;
    ap_uint<32> txBytes;
    ap_uint<32> byteCnt;
    ap_uint<32> wordCnt;
    ap_uint<32> metaCnt;
    ap_uint<32> pktNum;

    count = 0;
    session = 1;
    txBytes = 15*1024;
    pkt_size = 1024;
    byteCnt = 0;
    wordCnt = 0;
    metaCnt = 0;
    pktNum = txBytes/pkt_size;
    base_addr = 0;
    buff_size = 20240;

    bool isHeader = true;

    while(count < 1000)
    {
        ap_start_pulse = 0;
        
        if (count == 0)
            ap_start_pulse = 1;

        if (metaCnt < pktNum)
        {
            ap_uint<64> meta;
            meta(31,0) = session;
            meta(63,32) = pkt_size;
            wr_meta.write(meta);
            metaCnt ++;
        }
        

    	if (wordCnt < ntransfers(txBytes))
		{
			wordCnt ++;
			inword.data = wordCnt;
			inword.last = (wordCnt == ntransfers(txBytes)) | (wordCnt % ntransfers(pkt_size) ==0);
			wr_data.write(inword);
			golden.write(inword);
			
		}

    	host_wr_handler(
               host_wr_data,
               host_wr_req,
               wr_data, 
               wr_meta,
               base_addr,
               buff_size,
               ap_start_pulse
                );

    	if (!host_wr_req.empty())
    	{
    		reqIntf wr_req(host_wr_req.read());
    		cout<<"addr: "<<wr_req.vaddr<<" bytes: "<<wr_req.len<<" at cycle "<<count<<endl;
    	}


    	if (!host_wr_data.empty())
    	{
            outword = host_wr_data.read();
            goldenword = golden.read();

    		if (isHeader)
            {
                cout<<"sequence number:"<<outword.data(511,448)<<" wrapAround:"<<outword.data(447,384)<< " tx data(383,0) "<<outword.data(383,0)<<" last "<<outword.last<<" goldenword(383,0) "<<goldenword.data(383,0)<<" last "<<goldenword.last<<endl;
                isHeader = false;
            } else {
                cout<<"tx data "<<outword.data<<" last "<<outword.last<<" goldenword "<<goldenword.data<<" last "<<goldenword.last<<endl;
                if(outword.data != goldenword.data) return 1;
                if (outword.last)
                {
                    isHeader = true;
                }
                
            }
            
            
            			
    	}


    	count++;
    }


	
	return 0;
}