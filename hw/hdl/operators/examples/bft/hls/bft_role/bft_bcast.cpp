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


typedef ap_axiu<DWIDTH512, 0, 0, 0> pkt512;
typedef ap_axiu<DWIDTH256, 0, 0, 0> pkt256;
typedef ap_axiu<DWIDTH128, 0, 0, 0> pkt128;
typedef ap_axiu<DWIDTH64, 0, 0, 0> pkt64;
typedef ap_axiu<DWIDTH32, 0, 0, 0> pkt32;
typedef ap_axiu<DWIDTH16, 0, 0, 0> pkt16;
typedef ap_axiu<DWIDTH8, 0, 0, 0> pkt8;

#ifndef __SYNTHESIS__
void printPktWordByByte (net_axis<512> currWord);
#endif

// The bcast data is stored in a bram for iterative reading and 
// the scatter data is consumed sequentially from the input stream
// This function splits the input stream to two streams according to the command information
// Each output streams are asserted with proper last signal
void bcast_stream_handler(
                hls::stream<headerType>& s_meta,
                hls::stream<net_axis<512> >& s_axis,
                hls::stream<headerType>& m_meta,
                hls::stream<net_axis<512> >& m_axis
                )
{

#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

	enum StateType {PARSE_CMD, BCAST_CMD, BCAST_DATA};
    static StateType State = PARSE_CMD;

    static net_axis<512> bcast_buffer[BCAST_BUF_DEPTH];
    #pragma HLS bind_storage variable=bcast_buffer type=RAM_2P impl=BRAM
	#pragma HLS DEPENDENCE variable=bcast_buffer inter false

    static net_axis<512> currWord;

    static headerType headerWord;

    static ap_uint<32> procWord = 0;

    static ap_uint<32> currRank = 0;
    
    switch(State)
    {
        case PARSE_CMD:
            if (!s_meta.empty())
            {
                headerWord = s_meta.read();
                State = BCAST_CMD;
            }
        break;
        case BCAST_CMD:
            // write the header out if current rank doesn't equal to local rank
            if(currRank != headerWord.src){
                headerWord.dst = currRank;
                m_meta.write(headerWord);
                State = BCAST_DATA;
            }
            currRank++;
        break;
        case BCAST_DATA:
            // if this is the first payload of the bcast scatter primitive
            // read the whole bcast payload, send it to the tx net stream
            // and stores it into the bcast bram
            if (currRank == 1)
            {
                if (!s_axis.empty())
                {
                    net_axis<512> currDataWord = s_axis.read();
                    net_axis<512> bcastStreamWord;
                    
                    // write to bcast
                    bcastStreamWord.data = currDataWord.data;
                    bcastStreamWord.keep = currDataWord.keep;
                    bcastStreamWord.last = currDataWord.last;
                                 
                    // store to the bcast bram
                    bcast_buffer[procWord].data = currDataWord.data;
                    bcast_buffer[procWord].keep = currDataWord.keep;
                    bcast_buffer[procWord].last = currDataWord.last;

                    m_axis.write(bcastStreamWord);
                    
                    procWord ++;
                    
                    if (bcastStreamWord.last)
                    {
                        procWord = 0;
                        if (currRank == headerWord.totalRank)
                        {
                            currRank = 0;
                            State = PARSE_CMD;
                        }
                        else 
                        {
                            State = BCAST_CMD;
                        }
                    }
                  
                    #ifndef __SYNTHESIS__
                    // printPktWordByByte(bcastStreamWord);
                    // std::cout<<"BCAST_DATA bcastStream "<<std::hex<<bcastStreamWord.data<<" last "<<bcastStreamWord.last<<std::endl;
                    #endif
                }
            }
            // if not the first bcast payload, read from the bcast bram
            else
            {
                // write to bcast
                net_axis<512> bcastStreamWord;
                bcastStreamWord.data = bcast_buffer[procWord].data;
                bcastStreamWord.keep = bcast_buffer[procWord].keep;
                bcastStreamWord.last = bcast_buffer[procWord].last;

                m_axis.write(bcastStreamWord);

                procWord ++;

                if (bcastStreamWord.last)
                {
                    procWord = 0;
                    if (currRank == headerWord.totalRank)
                    {
                        currRank = 0;
                        State = PARSE_CMD;
                    }
                    else 
                    {
                        State = BCAST_CMD;
                    }
                }
                
                #ifndef __SYNTHESIS__
                // printPktWordByByte(bcastStreamWord);
                // std::cout<<"BCAST_DATA bcastStream "<<std::hex<<bcastStreamWord.data<<" last "<<bcastStreamWord.last<<std::endl;
                #endif
            }
        break;
    }

}


// Assume the bft command is 64-bytes padded with assuming the start of the scatter len array is 64-byte aligned
// Assume each data and signature field is 64-bytes aligned 
void bft_bcast(
                hls::stream<headerType >& s_meta,
                hls::stream<pkt512 >& s_axis,
                hls::stream<headerType>& m_meta,
                hls::stream<pkt512 >& m_axis
                )
{
#pragma HLS INTERFACE axis register  port=s_meta
#pragma HLS INTERFACE axis register  port=s_axis
#pragma HLS INTERFACE axis register  port=m_meta
#pragma HLS INTERFACE axis register  port=m_axis
#pragma HLS aggregate variable=s_meta compact=bit
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

    bcast_stream_handler(
                s_meta,
                s_axis_internal,
                m_meta,
                m_axis_internal
                );

}
