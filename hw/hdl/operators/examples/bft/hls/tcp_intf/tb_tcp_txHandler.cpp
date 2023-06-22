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


void tcp_txHandler(
               hls::stream<pkt512 >& s_data_in,
               hls::stream<ap_uint<64> >& cmd_txHandler,
               hls::stream<ap_uint<32> >& m_axis_tcp_tx_meta, 
               hls::stream<pkt512>& m_axis_tcp_tx_data, 
               hls::stream<ap_uint<64> >& s_axis_tcp_tx_status,
			   ap_uint<32> maxPkgWord
                );


int main()
{
	hls::stream<pkt512 > s_data_in;
    hls::stream<ap_uint<64> > cmd_txHandler;
    hls::stream<ap_uint<32> > m_axis_tcp_tx_meta;
    hls::stream<pkt512> m_axis_tcp_tx_data; 
    hls::stream<ap_uint<64> > s_axis_tcp_tx_status;

    stream<ap_axiu<DATA_WIDTH,0,0,0> > golden;

    int count ;
    int session ;
    int txByte ;
    int maxPkgWordCnt ;

    int sentWordCnt ;

    ap_axiu<DATA_WIDTH,0,0,0> inword;
	ap_axiu<DATA_WIDTH,0,0,0> outword;
	ap_axiu<DATA_WIDTH,0,0,0> goldenword;

	count = 0;
    session = 0;
    txByte = 10*1024;
    maxPkgWordCnt = 16;
    sentWordCnt = 0;

	cout<<"maxPkgWordCnt "<<maxPkgWordCnt<<endl;

    while(count < 5000)
    {
    	if (count == 1)
    	{
    		ap_uint<64> cmd;
    		cmd(31,0) = session;
    		cmd(63,32) = txByte;
    		// cmd(95,64) = maxPkgWordCnt;
    		cmd_txHandler.write(cmd);
    		cout<<"cmd session "<<cmd(31,0)<<" txByte "<<cmd(63,32)<<endl;
    	}


		if (sentWordCnt < ntransfers(txByte))
		{
			sentWordCnt ++;
			inword.data = sentWordCnt;
			inword.last = (sentWordCnt%maxPkgWordCnt == 0) | (sentWordCnt == ntransfers(txByte));
			s_data_in.write(inword);
			golden.write(inword);
			
		}


    	tcp_txHandler(
               s_data_in,
               cmd_txHandler,
               m_axis_tcp_tx_meta, 
               m_axis_tcp_tx_data, 
               s_axis_tcp_tx_status,
			   maxPkgWordCnt
                );

    	if (!m_axis_tcp_tx_meta.empty())
    	{
    		ap_uint<32> tx_meta_pkt = m_axis_tcp_tx_meta.read();
    		ap_uint<16> session = tx_meta_pkt(15,0);
    		ap_uint<16> length = tx_meta_pkt(31,16);
    		ap_uint<64> tx_status_pkt;
    		tx_status_pkt(15,0) = session;
    		tx_status_pkt(31,16) = length;
    		tx_status_pkt(63,62) = 0; //rand() % 2;
    		s_axis_tcp_tx_status.write(tx_status_pkt);
    		cout<<"tx meta session "<<session<<" length "<<length<<" tx status error "<<tx_status_pkt(63,62)<<" at cycle "<<count<<endl;
    	}

    	if (!m_axis_tcp_tx_data.empty())
    	{
    		outword = m_axis_tcp_tx_data.read();
			goldenword = golden.read();
			cout<<"tx data "<<outword.data<<" last "<<outword.last<<" goldenword "<<goldenword.data<<" last "<<goldenword.last<<" at cycle "<<count<<endl;
			if(outword.data != goldenword.data) return 1;
			if(outword.last != goldenword.last) return 1;
    	}

    	count ++;
    }


    count = 0;
    session = 0;
    txByte = 512;
    maxPkgWordCnt = 16;
    sentWordCnt = 0;

	cout<<"maxPkgWordCnt "<<maxPkgWordCnt<<endl;

    while(count < 5000)
    {
    	if (count == 1)
    	{
    		ap_uint<64> cmd;
    		cmd(31,0) = session;
    		cmd(63,32) = txByte;
    		// cmd(95,64) = maxPkgWordCnt;
    		cmd_txHandler.write(cmd);
    		cout<<"cmd session "<<cmd(31,0)<<" txByte "<<cmd(63,32)<<endl;
    	}


		if (sentWordCnt < ntransfers(txByte))
		{
			sentWordCnt ++;
			inword.data = sentWordCnt;
			inword.last = (sentWordCnt%maxPkgWordCnt == 0) | (sentWordCnt == ntransfers(txByte));
			s_data_in.write(inword);
			golden.write(inword);
			
		}


    	tcp_txHandler(
               s_data_in,
               cmd_txHandler,
               m_axis_tcp_tx_meta, 
               m_axis_tcp_tx_data, 
               s_axis_tcp_tx_status,
			   maxPkgWordCnt
                );

    	if (!m_axis_tcp_tx_meta.empty())
    	{
    		ap_uint<32> tx_meta_pkt = m_axis_tcp_tx_meta.read();
    		ap_uint<16> session = tx_meta_pkt(15,0);
    		ap_uint<16> length = tx_meta_pkt(31,16);
    		ap_uint<64> tx_status_pkt;
    		tx_status_pkt(15,0) = session;
    		tx_status_pkt(31,16) = length;
    		tx_status_pkt(63,62) = 0; //rand() % 2;
    		s_axis_tcp_tx_status.write(tx_status_pkt);
    		cout<<"tx meta session "<<session<<" length "<<length<<" tx status error "<<tx_status_pkt(63,62)<<" at cycle "<<count<<endl;
    	}

    	if (!m_axis_tcp_tx_data.empty())
    	{
    		outword = m_axis_tcp_tx_data.read();
			goldenword = golden.read();
			cout<<"tx data "<<outword.data<<" last "<<outword.last<<" goldenword "<<goldenword.data<<" last "<<goldenword.last<<endl;
			if(outword.data != goldenword.data) return 1;
			if(outword.last != goldenword.last) return 1;
    	}

    	count ++;
    }


	return 0;
}