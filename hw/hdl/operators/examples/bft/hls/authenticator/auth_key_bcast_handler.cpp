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

// This means the largest bcast length
#define BCAST_BUF_DEPTH 128 //128 * 64 bytes -> 8 KB

// The bcast data is stored in a bram for iterative reading
void auth_key_bcast_handler(
                hls::stream<pkt512 >& bcastInStream,
                hls::stream<pkt512 >& bcastOutStream,
                ap_uint<32> bcast_factor
                )
{
#pragma HLS INTERFACE axis register port=bcastInStream
#pragma HLS INTERFACE axis register port=bcastOutStream
#pragma HLS INTERFACE ap_stable register port=bcast_factor
#pragma HLS INTERFACE ap_ctrl_none port=return

#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

	enum StateType {WAIT_BCAST_DATA, TRANSFER_BCAST_DATA};
    static StateType State = WAIT_BCAST_DATA;

    static pkt512 bcast_buffer[BCAST_BUF_DEPTH];
	#pragma HLS RESOURCE variable=bcast_buffer core=RAM_2P_BRAM
	#pragma HLS DEPENDENCE variable=bcast_buffer inter false

    static ap_uint<32> bcastStreamLen = 0;
    static ap_uint<32> procWord = 0;
    static ap_uint<32> bcastRoundCnt = 0;

    switch(State)
    {
        case WAIT_BCAST_DATA:
            // stores it into the bcast bram
            if (!bcastInStream.empty())
            {
                pkt512 currDataWord = bcastInStream.read();
                      
                // store to the bcast bram
                bcast_buffer[bcastStreamLen] = currDataWord;
                
                bcastStreamLen ++;

                if (currDataWord.last)
                {
                    State = TRANSFER_BCAST_DATA;
                }
                #ifndef __SYNTHESIS__
                std::cout<<"Input BCAST_DATA bcastStream "<<std::hex<<currDataWord.data<<" last "<<currDataWord.last<<std::endl;
                #endif
            }
        break;
        case TRANSFER_BCAST_DATA:
            // write to network tx 
            pkt512 bcastStreamWord;
            bcastStreamWord = bcast_buffer[procWord];
            bcastOutStream.write(bcastStreamWord);

            procWord ++;
            
            if (procWord == bcastStreamLen)
            {
                procWord = 0;
                bcastRoundCnt ++;
                if (bcastRoundCnt == bcast_factor)
                {
                    bcastStreamLen = 0;
                    bcastRoundCnt = 0;
                    State = WAIT_BCAST_DATA;
                }
                
            }
            #ifndef __SYNTHESIS__
            std::cout<<"Output BCAST_DATA bcastStream "<<std::hex<<bcastStreamWord.data<<" last "<<bcastStreamWord.last<<std::endl;
            #endif
        break;
    }

}