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

void printPktWordByByte (pkt512 currWord)
{
    cout<<"data: ";
    for (size_t i = 0; i < 64; i++)
    {
        if (currWord.keep(i,i))
        {
            cout<<std::hex<<currWord.data(7+i*8, i*8)<<" ";
        }
    }
    cout<<endl;
    cout<<"keep: "<<currWord.keep<<" last: "<<currWord.last<<endl;   
}

void sha_bit_padding(	
                        hls::stream<ap_uint<32> >& meta,
                        hls::stream<pkt512>& stream,
                        hls::stream<pkt512>& padded_stream
);

int main()
{
	hls::stream<ap_uint<32> > meta;
    hls::stream<pkt512 > stream;
    hls::stream<pkt512 > padded_stream; 

    int count;
    count = 0;
    pkt512 currWord;

    meta.write(3);
    currWord.data = 0x636261;
    currWord.keep = 0x3F;
    currWord.last = 1;
    stream.write(currWord);
    printPktWordByByte(currWord);

    meta.write(56);
    for (size_t i = 0; i < 56; i++)
    {
        currWord.data(7+i*8, i*8) = 0x61 + i;
    }
    currWord.keep = 0xFFFFFFFFFFFFFF;
    currWord.last = 1;
    stream.write(currWord);
    printPktWordByByte(currWord);

    meta.write(64);
    for (size_t i = 0; i < 64; i++)
    {
        currWord.data(7+i*8, i*8) = 0x61 + i;
    }
    currWord.keep = 0xFFFFFFFFFFFFFFFF;
    currWord.last = 1;
    stream.write(currWord);
    printPktWordByByte(currWord);

    cout<<"\nfinished enqueue intput\n"<<endl;

    while(count < 1000)
    {

    	sha_bit_padding(	
                        meta,
                        stream,
                        padded_stream);

    	if (!padded_stream.empty())
    	{
            pkt512 outword = padded_stream.read();
            printPktWordByByte(outword);
    	}

    	count++;
    }


	
	return 0;
}