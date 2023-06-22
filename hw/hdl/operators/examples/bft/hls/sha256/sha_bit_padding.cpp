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

#ifndef __SYNTHESIS__
void printPktWordByByte (pkt512 currWord);
#endif

void sha_bit_padding(	
                        hls::stream<ap_uint<64> >& meta,
                        hls::stream<pkt512>& stream,
                        hls::stream<pkt512>& padded_stream
)
{
#pragma HLS INTERFACE axis register  port=meta
#pragma HLS INTERFACE axis register  port=stream
#pragma HLS INTERFACE axis register  port=padded_stream
#pragma HLS INTERFACE ap_ctrl_none port=return

	#pragma HLS PIPELINE II=1
	#pragma HLS INLINE off

	enum fsmStateType {META, MSG, EXTRA_WORD};
    static fsmStateType  fsmState = META;

	static ap_uint<64> byteLen;
	static ap_uint<32> wordLen;
	static ap_uint<32> paddedWordLen;
	static ap_uint<64> bitLen;
	static ap_uint<32> append_bit_pos;
	static ap_uint<32> wordCnt = 0;
	static bool append_len_at_new_word = false;
	static bool append_bit_at_new_word = false;
	static ap_uint<512> bit_append_word = 1;
	static ap_uint<512> len_append_word = 0;

    switch (fsmState)
    {
    case META:
        if (!meta.empty())
        {
            byteLen = meta.read();
            bitLen = byteLen * 8;
			wordLen = (byteLen + 63) >> 6;
			paddedWordLen = (bitLen + 1 + 64 + 511) >> 9;
			append_len_at_new_word = paddedWordLen > wordLen;
			len_append_word(511,504) = bitLen(7,0);
			len_append_word(503,496) = bitLen(15,8);
			len_append_word(495,488) = bitLen(23,16);
			len_append_word(487,480) = bitLen(31,24);
			len_append_word(479,472) = bitLen(39,32);
			len_append_word(471,464) = bitLen(47,40);
			len_append_word(463,456) = bitLen(55,48);
			len_append_word(455,448) = bitLen(63,56);
			
			append_bit_pos = bitLen - (wordLen - 1) * 512;
			append_bit_at_new_word = append_bit_pos == 512;
			bit_append_word =  bit_append_word << append_bit_pos(8,0);

			#ifndef __SYNTHESIS__
			std::cout<<"sha_bit_padding META state: ";
			std::cout<<"byteLen:"<<dec<<byteLen<<" paddedWordLen:"<<paddedWordLen<<" append_bit_at_new_word:"<<append_bit_at_new_word<<" append_bit_pos:"<<append_bit_pos<<" append_len_at_new_word:"<<append_len_at_new_word<<std::endl;
			std::cout<<"len_append_word:"<<hex<<len_append_word<<std::endl;
			std::cout<<"bit_append_word:"<<bit_append_word<<std::endl;
			#endif
			
            fsmState = MSG;
        }
        break;
    case MSG:
        if (!stream.empty())
		{
			pkt512 currWord = stream.read();
			pkt512 outWord;
			outWord.data = currWord.data;
			outWord.keep = 0xFFFFFFFFFFFFFFFF;
			outWord.last = currWord.last & (append_len_at_new_word == 0);
			wordCnt ++;
			if (wordCnt == wordLen)
			{
				if (append_bit_at_new_word == 0)
				{
					outWord.data = outWord.data | bit_append_word;
				}
				if (append_len_at_new_word == 0)
				{
					outWord.data = outWord.data | len_append_word;
					wordCnt = 0;
					bit_append_word = 1;
					len_append_word = 0;
					fsmState = META;
				} else {
					wordCnt = 0;
					fsmState = EXTRA_WORD;
				}
			}
			#ifndef __SYNTHESIS__
			std::cout<<"sha_bit_padding MSG state: ";
			printPktWordByByte(outWord);
			#endif
			padded_stream.write(outWord);
		}
        break;
	case EXTRA_WORD:
		pkt512 outWord;
		outWord.data = 0;
		outWord.keep = 0xFFFFFFFFFFFFFFFF;
		outWord.last = 1;
		if (append_bit_at_new_word == 1)
		{
			bit_append_word = 1 << append_bit_pos;
			outWord.data = outWord.data | bit_append_word;
		}
		outWord.data = outWord.data | len_append_word;
		padded_stream.write(outWord);
		bit_append_word = 1;
		len_append_word = 0;
		#ifndef __SYNTHESIS__
		std::cout<<"sha_bit_padding EXTRA_WORD state: ";
		printPktWordByByte(outWord);
		#endif
		fsmState = META;
		break;
    }
}
