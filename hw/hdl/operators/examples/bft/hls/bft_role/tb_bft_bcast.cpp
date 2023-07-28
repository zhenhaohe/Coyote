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
#include "bft.hpp"
#include "utils.hpp"

using namespace hls;
using namespace std;

int ntransfers(int nbytes){
	int bytes_per_transfer = 512/8;
	return (nbytes+bytes_per_transfer-1)/bytes_per_transfer;
}

void bft_bcast(
                hls::stream<headerType >& s_meta,
                hls::stream<pkt512 >& s_axis,
                hls::stream<headerType>& m_meta,
                hls::stream<pkt512 >& m_axis
                );

int main()
{
    hls::stream<headerType > s_meta;
    hls::stream<pkt512 > s_axis;
    hls::stream<headerType > m_meta;
    hls::stream<pkt512 > m_axis;

    ap_uint<32> dataLen = 128; //total byte len of data to each primitive
    ap_uint<32> numNode = 4; //total node
    
    hls::stream<pkt512 > golden [(int)(numNode-1)];
    headerType hdrWord;
    pkt512 currWord;

    int numMsg = 2;

    for (int j=0; j<numMsg; j++)
    {
        // pack bft command, same scatter length of every field
        hdrWord.cmdID = 0;
        hdrWord.cmdLen = 64;
        hdrWord.dst = 0;
        hdrWord.src = 1;
        hdrWord.tag = 0;
        hdrWord.dataLen = dataLen;

        hdrWord.msgID = 0;
        hdrWord.msgType = 0;
        hdrWord.epochID = 0;
        hdrWord.totalRank = numNode;

        s_meta.write(hdrWord);
        hdrWord.print();
    }
    printf("Finished bft commands\n");
        
    for (int k=0; k<numMsg; k++)
    {    
        //pack bft bcast data
        for (size_t i = 0; i < ntransfers(dataLen); i++)
        {
            

            currWord.data = k*ntransfers(dataLen)+i;

            if ((i*64+64) < dataLen){
                currWord.keep = 0xFFFFFFFFFFFFFFFF;
            }
            else
            {
                ap_uint<6> remainingLen = dataLen-i*64;
                currWord.keep = (ap_uint<64>)lenToKeep(remainingLen);
            }
            if (i == ntransfers(dataLen)-1){
                currWord.last = 1;
            } else {
                currWord.last = 0;
            }
            
            s_axis.write(currWord);
            cout<<"s_axis "<<std::hex<<currWord.data<<" keep "<<currWord.keep<<" last "<<currWord.last<<endl;

            for (int n = 0; n<numNode-1; n++)
            {
                golden[n].write(currWord);
            }
        }
    }

    printf("Finished packing bft bcast data\n\n\n");
    

    int count = 0;
    pkt512 outword;
    pkt512 goldenword;
    headerType m_meta_word;
    ap_uint<32> outwordCnt = 0;
    int goldenInd = 0;

    while(count < 10000)
    {

    	bft_bcast(
            s_meta,
            s_axis,
            m_meta,
            m_axis
                );


        if (!m_meta.empty())
    	{
    		m_meta_word = m_meta.read();
			m_meta_word.print();
    	}


    	if (!m_axis.empty())
    	{
            outword = m_axis.read();
            
            goldenword = golden[goldenInd].read();
            cout<<"m_axis "<<std::hex<<outword.data<<" last "<<outword.last<<" golden data "<<goldenword.data<<" last "<<goldenword.last<<endl;
            outwordCnt++;
            if (outword.last){
                goldenInd++;
                goldenInd = goldenInd%(numNode-1);
            }
            if(outword.data != goldenword.data) return 1;    
            if(outword.last != goldenword.last) return 1;            
    	}


    	count++;
    }


	
	return 0;
    



}