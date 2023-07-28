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

#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    static pkt512 currWord;

    static headerType headerWord;


    enum StateType {HEADER, PAYLOAD};
    static StateType State = HEADER;

    switch(State)
    {
        case HEADER:
            if (!s_meta.empty())
            {
                currWord.data = 0;
                currWord.keep = 0xFFFFFFFFFFFFFFFF;
                currWord.last = 0;

                headerWord = s_meta.read();
                currWord.data(HEADER_LENGTH-1,0) = (ap_uint<HEADER_LENGTH>)headerWord;

                m_axis.write(currWord);
                State = PAYLOAD;
            }
        break;
        case PAYLOAD:
            if(!s_axis.empty())
            {
                currWord = s_axis.read();
                m_axis.write(currWord);
                if(currWord.last)
                {
                    State = HEADER;
                }
            }
        break;
    }
    
}