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


void bft_mux_meta(
                hls::stream<headerType>& s_meta_0,
                hls::stream<headerType>& s_meta_1,
                hls::stream<headerType>& m_meta,
                hls::stream<ap_uint<8> >& meta_int
                )
{

#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    static headerType headerWord;

    static ap_uint<8> dest = 0;

    if (!s_meta_0.empty()){
		headerWord = s_meta_0.read();
		m_meta.write(headerWord);
        dest = 0;
        meta_int.write(dest);
	} else if (!s_meta_1.empty()){
        headerWord = s_meta_1.read();
		m_meta.write(headerWord);
        dest = 1;
        meta_int.write(dest);
    }
}

void bft_mux_data(	
                hls::stream<ap_uint<8> >& meta_int,
                hls::stream<pkt512 >& s_axis_0,
                hls::stream<pkt512 >& s_axis_1,
                hls::stream<pkt512 >& m_axis
)
{
	#pragma HLS PIPELINE II=1
	#pragma HLS INLINE off

	enum fsmStateType {META, STREAM_0, STREAM_1};
    static fsmStateType  fsmState = META;

    static pkt512 currWord;

    switch (fsmState)
    {
    case META:
        if (!meta_int.empty())
        {
            ap_uint<8> dest = meta_int.read();
            if (dest == 0){
                fsmState = STREAM_0;
            } else {
                fsmState = STREAM_1;
            }
        }
        break;
    case STREAM_0:
        if (!s_axis_0.empty())
        {
            currWord = s_axis_0.read();
            m_axis.write(currWord);
            if (currWord.last)
            {
                fsmState = META;
            }
        }
        break;
    case STREAM_1:
        if (!s_axis_1.empty())
        {
            currWord = s_axis_1.read();
            m_axis.write(currWord);
            if (currWord.last)
            {
                fsmState = META;
            }
        }
        break;
    }
} 

void bft_mux(
                hls::stream<headerType >& s_meta_0,
                hls::stream<pkt512 >& s_axis_0,
                hls::stream<headerType >& s_meta_1,
                hls::stream<pkt512 >& s_axis_1,
                hls::stream<headerType>& m_meta,
                hls::stream<pkt512 >& m_axis
                )
{
#pragma HLS INTERFACE axis register  port=s_meta_0
#pragma HLS INTERFACE axis register  port=s_axis_0
#pragma HLS INTERFACE axis register  port=s_meta_1
#pragma HLS INTERFACE axis register  port=s_axis_1
#pragma HLS INTERFACE axis register  port=m_meta
#pragma HLS INTERFACE axis register  port=m_axis
#pragma HLS aggregate variable=s_meta_0 compact=bit
#pragma HLS aggregate variable=s_meta_1 compact=bit
#pragma HLS aggregate variable=m_meta compact=bit

#pragma HLS INTERFACE ap_ctrl_none port=return

#pragma HLS DATAFLOW disable_start_propagation

    static hls::stream<ap_uint<8> > meta_int;
	#pragma HLS STREAM depth=16 variable=meta_int

    bft_mux_meta(
                s_meta_0,
                s_meta_1,
                m_meta,
                meta_int
                );

    bft_mux_data(	
                meta_int,
                s_axis_0,
                s_axis_1,
                m_axis
    );

}
