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


void bft_arbiter_meta(
                hls::stream<headerType>& s_meta,
                hls::stream<headerType>& m_meta_0,
                hls::stream<headerType>& m_meta_1,
                hls::stream<ap_uint<32> >& meta_int
                )
{

#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    static headerType headerWord;

    static ap_uint<32> dest = 0;

    if (!s_meta.empty()){
		headerWord = s_meta.read();
        if (headerWord.cmdID == NET_OFFLOAD){
            m_meta_0.write(headerWord);
            dest = headerWord.cmdID;
            meta_int.write(dest);
        } else if (headerWord.cmdID == AUTH_OFFLOAD) {
            m_meta_1.write(headerWord);
            dest = headerWord.cmdID;
            meta_int.write(dest);
        }
		
	} 
}

void bft_arbiter_data(	
                hls::stream<ap_uint<32> >& meta_int,
                hls::stream<pkt512 >& s_axis,
                hls::stream<pkt512 >& m_axis_0,
                hls::stream<pkt512 >& m_axis_1
)
{
	#pragma HLS PIPELINE II=1
	#pragma HLS INLINE off

	enum fsmStateType {META, NET_STREAM, AUTH_STREAM};
    static fsmStateType  fsmState = META;

    static pkt512 currWord;

    switch (fsmState)
    {
    case META:
        if (!meta_int.empty())
        {
            ap_uint<32> dest = meta_int.read();
            if (dest == NET_OFFLOAD){
                fsmState = NET_STREAM;
            } else if (dest == AUTH_OFFLOAD){
                fsmState = AUTH_STREAM;
            }
        }
        break;
    case NET_STREAM:
        if (!s_axis.empty())
        {
            currWord = s_axis.read();
            m_axis_0.write(currWord);
            if (currWord.last)
            {
                fsmState = META;
            }
        }
        break;
    case AUTH_STREAM:
        if (!s_axis.empty())
        {
            currWord = s_axis.read();
            m_axis_1.write(currWord);
            if (currWord.last)
            {
                fsmState = META;
            }
        }
        break;
    }
} 

void bft_arbiter(
                hls::stream<headerType >& s_meta,
                hls::stream<pkt512 >& s_axis,
                hls::stream<headerType >& m_meta_0,
                hls::stream<pkt512 >& m_axis_0,
                hls::stream<headerType>& m_meta_1,
                hls::stream<pkt512 >& m_axis_1
                )
{
#pragma HLS INTERFACE axis register  port=s_meta
#pragma HLS INTERFACE axis register  port=s_axis
#pragma HLS INTERFACE axis register  port=m_meta_0
#pragma HLS INTERFACE axis register  port=m_axis_0
#pragma HLS INTERFACE axis register  port=m_meta_1
#pragma HLS INTERFACE axis register  port=m_axis_1
#pragma HLS aggregate variable=s_meta compact=bit
#pragma HLS aggregate variable=m_meta_0 compact=bit
#pragma HLS aggregate variable=m_meta_1 compact=bit

#pragma HLS INTERFACE ap_ctrl_none port=return

#pragma HLS DATAFLOW disable_start_propagation

    static hls::stream<ap_uint<32> > meta_int;
	#pragma HLS STREAM depth=16 variable=meta_int

    bft_arbiter_meta(
                s_meta,
                m_meta_0,
                m_meta_1,
                meta_int
                );

    bft_arbiter_data(	
                meta_int,
                s_axis,
                m_axis_0,
                m_axis_1
    );

}