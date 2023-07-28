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


using namespace hls;
using namespace std;


// Assume the header has the following format and generate the meta information
// struct headerType
// {
//     ap_uint<32> cmdID; // specifier of different communication primitive
//     ap_uint<32> cmdLen; // total byte len of compulsory & optional cmd fields
//     ap_uint<32> dst; // either dst rank or communicator ID depends on primitive
//     ap_uint<32> src; // src rank
//     ap_uint<32> tag; // tag, reserved
//     ap_uint<32> dataLen; //total byte len of data to each primitive
//     ap_uint<32> msgID;
//     ap_uint<32> msgType;
//     ap_uint<32> epochID;
//     ap_uint<32> totalRank;
// };

void bft_meta_gen (
            hls::stream<pkt512 >& s_axis,
            hls::stream<pkt512 >& m_axis,
            hls::stream<ap_uint<64> >& m_meta
)
{
#pragma HLS INTERFACE axis register  port=s_axis
#pragma HLS INTERFACE axis register  port=m_axis
#pragma HLS INTERFACE axis register  port=m_meta
#pragma HLS INTERFACE ap_ctrl_none port=return

#pragma HLS PIPELINE II=1
#pragma HLS INLINE off


    static pkt512 currWord, header;
    static ap_uint<64> meta;
    enum FsmStateType {HEADER, DATA};
    static FsmStateType  State = HEADER;

    switch (State)
    {
    case HEADER:
        if (!s_axis.empty())
        {
            header = s_axis.read();
            ap_uint<32> dstRank = header.data(95,64);
            ap_uint<32> cmdLen = header.data(63,32);
            ap_uint<32> dataLen = header.data(191,160);
            meta(31,0) = dstRank;
            meta(63,32) = cmdLen + dataLen;
            
            m_meta.write(meta);
            m_axis.write(header);

            State = DATA;
        }
        break;
    case DATA:
        if (!s_axis.empty())
        {
            pkt512 currWord = s_axis.read();
            m_axis.write(currWord);
            if (currWord.last)
            {
                State = HEADER;
            }
        }
        break;
    }
}