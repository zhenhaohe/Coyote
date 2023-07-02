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


typedef ap_axiu<DWIDTH512, 0, 0, 0> pkt512;
typedef ap_axiu<DWIDTH256, 0, 0, 0> pkt256;
typedef ap_axiu<DWIDTH128, 0, 0, 0> pkt128;
typedef ap_axiu<DWIDTH64, 0, 0, 0> pkt64;
typedef ap_axiu<DWIDTH32, 0, 0, 0> pkt32;
typedef ap_axiu<DWIDTH16, 0, 0, 0> pkt16;
typedef ap_axiu<DWIDTH8, 0, 0, 0> pkt8;


void hmac_eLen_handler(
               hls::stream<ap_uint<64> >& len_strm_in,
               hls::stream<ap_uint<64> >& len_strm_out,
               hls::stream<ap_uint<8> >& end_len_strm_out
                )
{
#pragma HLS INTERFACE axis register  port=len_strm_in
#pragma HLS INTERFACE axis register  port=len_strm_out
#pragma HLS INTERFACE axis register  port=end_len_strm_out
#pragma HLS INTERFACE ap_ctrl_none port=return

#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

	static ap_uint<64> len;
    static ap_uint<8> end_len;

    enum handlerFsmStateType {LEN, EXTRA_END_LEN};
    static handlerFsmStateType  handlerFsmState = LEN;

    switch (handlerFsmState)
    {
    case LEN:
        if (!len_strm_in.empty())
        {
            len = len_strm_in.read();
            len_strm_out.write(len);
            end_len = 0;
            end_len_strm_out.write(end_len);
            handlerFsmState = EXTRA_END_LEN;
        }
        break;
    case EXTRA_END_LEN:
        end_len = 1;
        end_len_strm_out.write(end_len);
        handlerFsmState = LEN;
        break;
    }

}