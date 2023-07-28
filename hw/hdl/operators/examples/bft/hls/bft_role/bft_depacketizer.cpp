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


// Parse the msgHeader
// The output of this FSM goes into a right shifter 
// and the msgHeader will be removed

void parseHeader(
                hls::stream<net_axis<512> >& streamIn,
                hls::stream<net_axis<512> >& streamOut,
                hls::stream<headerType >& msgHeader
                )
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    static net_axis<512> currWord;

    static headerType headerWord;

    static ap_uint<32> procWord = 0;
    static ap_uint<32> procDataLen = 0;

    static ap_uint<32> packetWord = 0;
 
    if (!streamIn.empty())
    {
        currWord = streamIn.read();

        // If it is the first word 
        // Assume msgHeader not more than a full word
        if (procWord == 0)
        {
            headerWord = headerType(currWord.data(HEADER_LENGTH-1,0));
            msgHeader.write(headerWord);

            packetWord = ((headerWord.cmdLen + headerWord.dataLen + 63) >> 6);
            procWord ++;

            #ifndef __SYNTHESIS__
            std::cout<<"parseHeader packetWord "<<std::dec<<packetWord<<std::endl;
            #endif
        } else {
            net_axis<512> outWord;
            outWord.data = currWord.data;
            outWord.keep = currWord.keep;
            outWord.last = 0;

            procWord ++;
            procDataLen = procDataLen + 64;

            if (procDataLen > headerWord.dataLen)
            {
                outWord.keep = lenToKeep(headerWord.dataLen + 64 - procDataLen);
                procDataLen = 0;
            }

            if (procWord == packetWord)
            {
                outWord.last = 1;
                procWord = 0;
            }                

            streamOut.write(outWord);
        }
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

                
    parseHeader(
            s_axis_internal,
            streamTmp1,
            m_meta
            );

    maskDataFromKeep<1>(   
                streamTmp1,
                m_axis_internal
    );

    
}