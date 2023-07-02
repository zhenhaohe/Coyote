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


// Parse the msgHeader and get the total length of the header
// The header is forwarded to a small buffer, the offset and the stream is forwarded to the left shifter
// The the header and the shifted stream are merged

void parseHeader(
                hls::stream<headerType >& msgHeaderIn,
                hls::stream<net_axis<512> >& streamIn,
                hls::stream<headerType >& msgHeaderOut,
                hls::stream<net_axis<512> >& streamOut,
                hls::stream<ap_uint<16> >& streamOutOffset
                )
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    static net_axis<512> currWord;

    static headerType headerWord;

    static ap_uint<32> offset = 0;

    enum StateType {HEADER, PAYLOAD};
    static StateType State = HEADER;

    switch(State)
    {
        case HEADER:
            if (!msgHeaderIn.empty())
            {
                headerWord = msgHeaderIn.read();
                offset = headerWord.cmdLen;
                msgHeaderOut.write(headerWord);
                State = PAYLOAD;
            }
        break;
        case PAYLOAD:
            if(!streamIn.empty())
            {
                currWord = streamIn.read();
                streamOut.write(currWord);
                streamOutOffset.write(offset);
                if(currWord.last)
                {
                    State = HEADER;
                }
            }
        break;
    }
}

void insertHeader(
                hls::stream<headerType >& msgHeaderIn,
                hls::stream<net_axis<512> >& strmIn,
                hls::stream<net_axis<512> >& strmOut
                )
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    enum fsmStateType {FIRST_WORD, REST};
    static fsmStateType  fsmState = FIRST_WORD;

    static net_axis<512> currWord;

    static headerType header;

    switch (fsmState)
    {
    case FIRST_WORD:
        if (!strmIn.empty() & !msgHeaderIn.empty())
        {
            header = msgHeaderIn.read();
            
            ap_uint<512> headerWord = 0;
            headerWord(31,0) = header.cmdID; 
            headerWord(63,32) = header.cmdLen; 
            headerWord(95,64) = header.dst; 
            headerWord(127,96) = header.src; 
            headerWord(159,128) = header.tag; 
            headerWord(191,160) = header.dataLen; 
            headerWord(223,192) = header.msgID;
            headerWord(255,224) = header.msgType; 
            headerWord(287,256) = header.epochID;
            headerWord(319,288) = header.totalRank; 
            
            currWord = strmIn.read();
            net_axis<512> outWord;
            outWord.data = currWord.data | headerWord;
            outWord.keep = currWord.keep | lenToKeep(header.cmdLen);
            outWord.last = currWord.last;
            strmOut.write(outWord);
            if (!currWord.last)
            {
                fsmState = REST;
            }
            #ifndef __SYNTHESIS__
			std::cout<<"insertHeader FIRST_WORD state: ";
			printPktWordByByte(outWord);
			#endif
        }
        break;
    case REST:
        if (!strmIn.empty())
        {
            net_axis<512> currWord = strmIn.read();
            strmOut.write(currWord);
            if (currWord.last)
            {
                fsmState = FIRST_WORD;
            }
            #ifndef __SYNTHESIS__
			std::cout<<"insertHeader REST state: ";
			printPktWordByByte(currWord);
			#endif
        }
        break;
    }
}


void bft_packetizer(
                        hls::stream<headerType >& s_meta,
                        hls::stream<pkt512 >& s_axis,
                        hls::stream<pkt512 >& m_axis
                        )
{
#pragma HLS INTERFACE axis register  port=m_axis
#pragma HLS INTERFACE axis register  port=s_meta
#pragma HLS INTERFACE axis register  port=s_axis
#pragma HLS aggregate variable=s_meta compact=bit
#pragma HLS INTERFACE ap_ctrl_none port=return

#pragma HLS DATAFLOW disable_start_propagation


    static hls::stream<net_axis<512> > m_axis_internal;
	#pragma HLS STREAM depth=2 variable=m_axis_internal
    static hls::stream<net_axis<512> > s_axis_internal;
	#pragma HLS STREAM depth=2 variable=s_axis_internal

	convert_net_axis_to_axis<512>(m_axis_internal, 
							m_axis);

	convert_axis_to_net_axis<512>(s_axis,
                            s_axis_internal);

    static hls::stream<headerType > headerTmp;
	#pragma HLS STREAM depth=2 variable=headerTmp

    static hls::stream<net_axis<512> > streamTmp1;
    #pragma HLS stream variable=streamTmp1 depth=2
    static hls::stream<ap_uint<16> > streamTmpOffset1;
    #pragma HLS stream variable=streamTmpOffset1 depth=2
    static hls::stream<net_axis<512> > streamTmp2;
    #pragma HLS stream variable=streamTmp2 depth=2

                
    parseHeader(
                s_meta,
                s_axis_internal,
                headerTmp,
                streamTmp1,
                streamTmpOffset1
                );

    lshiftWordByOctet<net_axis<512>, 512, 1>(
                streamTmpOffset1, 
                streamTmp1, 
                streamTmp2
                );

    insertHeader(
                headerTmp,
                streamTmp2,
                m_axis_internal
                );

    
}