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

#define DWIDTH512 512
#define DWIDTH256 256
#define DWIDTH128 128
#define DWIDTH64 64
#define DWIDTH32 32
#define DWIDTH16 16
#define DWIDTH8 8

#ifndef __SYNTHESIS__
void printPktWordByByte (net_axis<512> currWord);
#endif

typedef ap_axiu<DWIDTH512, 0, 0, 0> pkt512;
typedef ap_axiu<DWIDTH256, 0, 0, 0> pkt256;
typedef ap_axiu<DWIDTH128, 0, 0, 0> pkt128;
typedef ap_axiu<DWIDTH64, 0, 0, 0> pkt64;
typedef ap_axiu<DWIDTH32, 0, 0, 0> pkt32;
typedef ap_axiu<DWIDTH16, 0, 0, 0> pkt16;
typedef ap_axiu<DWIDTH8, 0, 0, 0> pkt8;


// Parse the msgHeader, this is specific to the msg structure
// Any change in the msg structure requires a change in this FSM
// The output of this FSM goes into a right shifter 
// and the msgHeader will be removed
void shiftHeader(
                hls::stream<net_axis<512> >& streamIn,
                hls::stream<net_axis<512> >& streamOut,
                hls::stream<ap_uint<16> >& streamOutOffset,
                hls::stream<headerType >& msgHeader
                )
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    static net_axis<512> currWord;

    static headerType headerWord;

    static ap_uint<32> procWord = 0;
    static ap_uint<32> offset = 0;
    static ap_uint<32> procLen = 0;
    static ap_uint<32> totalLen = 0;

    static ap_uint<32> packetWord = 0;
 
    if (!streamIn.empty())
    {
        currWord = streamIn.read();

        // If it is the first word 
        // Assume msgHeader doesn't consume a full word
        if (procWord == 0)
        {
            headerWord.cmdID = currWord.data(31,0); 
            headerWord.cmdLen = currWord.data(63,32); 
            headerWord.dst = currWord.data(95,64); 
            headerWord.src = currWord.data(127,96); 
            headerWord.tag = currWord.data(159,128); 
            headerWord.dataLen = currWord.data(191,160); 
            headerWord.msgID = currWord.data(223,192);
            headerWord.msgType = currWord.data(255,224); 
            headerWord.epochID = currWord.data(287,256); 
            headerWord.totalRank = currWord.data(319,288);
            msgHeader.write(headerWord);

            //Shift all the msgHeader
            offset = headerWord.cmdLen;
            packetWord = ((headerWord.cmdLen + headerWord.dataLen + 63) >> 6);
            totalLen = headerWord.cmdLen + headerWord.dataLen;
            #ifndef __SYNTHESIS__
            std::cout<<"shiftHeader packetWord "<<std::dec<<packetWord<<std::endl;
            #endif
        }
        
        net_axis<512> outWord;
        outWord.data = currWord.data;
        outWord.keep = currWord.keep;
        outWord.last = 0;

        procWord ++;
        procLen = procLen + 64;

        if (procLen > totalLen)
        {
            outWord.keep = lenToKeep(totalLen + 64 - procLen);
            procLen = 0;
        }

        if (procWord == packetWord)
        {
            outWord.last = 1;
            procWord = 0;
        }                

        streamOut.write(outWord);
        streamOutOffset.write(offset);
    }
}


void bft_depacketizer(
                        hls::stream<pkt512 >& s_axis,
                        hls::stream<headerType >& m_meta,
                        hls::stream<pkt512 >& m_axis
                        )
{
#pragma HLS INTERFACE axis register  port=s_axis
#pragma HLS INTERFACE axis register  port=m_meta
#pragma HLS INTERFACE axis register  port=m_axis
#pragma HLS aggregate variable=m_meta compact=bit
#pragma HLS INTERFACE ap_ctrl_none port=return

#pragma HLS DATAFLOW disable_start_propagation

    static hls::stream<net_axis<512> > s_axis_internal;
	#pragma HLS STREAM depth=2 variable=s_axis_internal
    static hls::stream<net_axis<512> > m_axis_internal;
	#pragma HLS STREAM depth=2 variable=m_axis_internal

	convert_axis_to_net_axis<512>(s_axis, 
							s_axis_internal);

	convert_net_axis_to_axis<512>(m_axis_internal, 
							m_axis);

    static hls::stream<net_axis<512> > streamTmp1;
    #pragma HLS stream variable=streamTmp1 depth=2
    static hls::stream<ap_uint<16> > streamTmpOffset1;
    #pragma HLS stream variable=streamTmpOffset1 depth=2
    static hls::stream<net_axis<512> > streamTmp2;
    #pragma HLS stream variable=streamTmp2 depth=2

                
    shiftHeader(
            s_axis_internal,
            streamTmp1,
            streamTmpOffset1,
            m_meta
            );

    rshiftWordByOctet<net_axis<512>, 512, 1>(
                streamTmpOffset1, 
                streamTmp1, 
                streamTmp2);

    maskDataFromKeep<1>(   
                streamTmp2,
                m_axis_internal
    );

    
}