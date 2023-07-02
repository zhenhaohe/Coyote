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

#pragma once

#include <hls_stream.h>
#include "ap_int.h"
#include <stdint.h>
#include <iostream>
#include <fstream>
#include <iomanip>

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

template <int D>
struct net_axis
{
	ap_uint<D>		data;
	ap_uint<D/8>	keep;
	ap_uint<1>		last;
	net_axis() {}
	net_axis(ap_uint<D> data, ap_uint<D/8> keep, ap_uint<1> last)
		:data(data), keep(keep), last(last) {}
};

template <int WIDTH>
void convert_net_axis_to_axis(hls::stream<net_axis<WIDTH> >& input,
							hls::stream<ap_axiu<WIDTH, 0, 0, 0> >& output)
{
#pragma HLS pipeline II=1

	net_axis<WIDTH> inputWord;
	ap_axiu<WIDTH, 0, 0, 0> outputWord;

	if (!input.empty())
	{
		inputWord = input.read();
		outputWord.data = inputWord.data;
		outputWord.keep = inputWord.keep;
		outputWord.last = inputWord.last;
		output.write(outputWord);
	}
}


template <int WIDTH>
void convert_axis_to_net_axis(hls::stream<ap_axiu<WIDTH, 0, 0, 0> >& input,
							hls::stream<net_axis<WIDTH> >& output)
{
#pragma HLS pipeline II=1

	ap_axiu<WIDTH, 0, 0, 0> inputWord;
	net_axis<WIDTH> outputWord;
	
	if (!input.empty())
	{
		inputWord = input.read();
		outputWord.data = inputWord.data;
		outputWord.keep = inputWord.keep;
		outputWord.last = inputWord.last;
		output.write(outputWord);
	}
}

// The 2nd template parameter is a hack to use this function multiple times
template <typename T, int W, int whatever>
inline void lshiftWordByOctet(	ap_uint<16> & offset,
						hls::stream<T>& input,
						hls::stream<T>& output)
{
#pragma HLS inline off
#pragma HLS pipeline II=1
	static bool ls_firstWord = true;
	static bool ls_writeRemainder = false;
	static T prevWord;

	T currWord;
	T sendWord;

	//TODO use states
	if (ls_writeRemainder)
	{
		sendWord.data((8*offset)-1, 0) = prevWord.data((W-1), W-(8*offset));
		sendWord.data((W-1), (8*offset)) = 0;
		sendWord.keep(offset-1, 0) = prevWord.keep((W/8-1), (W/8)-offset);
		sendWord.keep((W/8-1), offset) = 0;
		sendWord.last = 1;

		output.write(sendWord);
		ls_writeRemainder = false;
	}
	else if (!input.empty() )
	{
		input.read(currWord);

		if (offset == 0)
		{
			output.write(currWord);
		}
		else
		{

			if (ls_firstWord)
			{
				sendWord.data((8*offset)-1, 0) = 0;
				sendWord.data((W-1), (8*offset)) = currWord.data((W-1)-(8*offset), 0);
				sendWord.keep(offset-1, 0) = 0xFFFFFFFF;
				sendWord.keep((W/8-1), offset) = currWord.keep((W/8-1)-offset, 0);
				sendWord.last = (currWord.keep((W/8-1), (W/8)-offset) == 0);
			}
			else
			{
				sendWord.data((8*offset)-1, 0) = prevWord.data((W-1), W-(8*offset));
				sendWord.data((W-1), (8*offset)) = currWord.data((W-1)-(8*offset), 0);

				sendWord.keep(offset-1, 0) = prevWord.keep((W/8-1), (W/8)-offset);
				sendWord.keep((W/8-1), offset) = currWord.keep((W/8-1)-offset, 0);

				sendWord.last = (currWord.keep((W/8-1), (W/8)-offset) == 0);

			}
			output.write(sendWord);

			prevWord = currWord;
			ls_firstWord = false;
			if (currWord.last)
			{
				ls_firstWord = true;
				ls_writeRemainder = !sendWord.last;
			}
		} //else offset
	}
}

// The 2nd template parameter is a hack to use this function multiple times
template <typename T, int W, int whatever>
inline void lshiftWordByOctet(	hls::stream<ap_uint<16> >& shiftOffset,
						hls::stream<T>& input,
						hls::stream<T>& output)
{
#pragma HLS inline off
#pragma HLS pipeline II=1
	static bool ls_firstWord = true;
	static bool ls_writeRemainder = false;
	static T prevWord;
    static ap_uint<16> offset;

	T currWord;
	T sendWord;

	//TODO use states
	if (ls_writeRemainder)
	{
		sendWord.data((8*offset)-1, 0) = prevWord.data((W-1), W-(8*offset));
		sendWord.data((W-1), (8*offset)) = 0;
		sendWord.keep(offset-1, 0) = prevWord.keep((W/8-1), (W/8)-offset);
		sendWord.keep((W/8-1), offset) = 0;
		sendWord.last = 1;

		output.write(sendWord);
		ls_writeRemainder = false;
	}
	else if (!input.empty() & !shiftOffset.empty())
	{
		input.read(currWord);
        shiftOffset.read(offset);

		if (offset == 0)
		{
			output.write(currWord);
		}
		else
		{

			if (ls_firstWord)
			{
				sendWord.data((8*offset)-1, 0) = 0;
				sendWord.data((W-1), (8*offset)) = currWord.data((W-1)-(8*offset), 0);
				sendWord.keep(offset-1, 0) = 0xFFFFFFFF;
				sendWord.keep((W/8-1), offset) = currWord.keep((W/8-1)-offset, 0);
				sendWord.last = (currWord.keep((W/8-1), (W/8)-offset) == 0);
			}
			else
			{
				sendWord.data((8*offset)-1, 0) = prevWord.data((W-1), W-(8*offset));
				sendWord.data((W-1), (8*offset)) = currWord.data((W-1)-(8*offset), 0);

				sendWord.keep(offset-1, 0) = prevWord.keep((W/8-1), (W/8)-offset);
				sendWord.keep((W/8-1), offset) = currWord.keep((W/8-1)-offset, 0);

				sendWord.last = (currWord.keep((W/8-1), (W/8)-offset) == 0);

			}
			output.write(sendWord);

			prevWord = currWord;
			ls_firstWord = false;
			if (currWord.last)
			{
				ls_firstWord = true;
				ls_writeRemainder = !sendWord.last;
			}
		} //else offset
	}
}

template <typename T, int W, int whatever>
inline void rshiftWordByOctet(	ap_uint<16>& offset,
						hls::stream<T>& input,
						hls::stream<T>& output)
{
#pragma HLS inline off
#pragma HLS pipeline II=1 //TODO this has a bug, the bug might come from how it is used

	enum fsmStateType {PKG, REMAINDER};
	static fsmStateType fsmState = PKG;
	static bool rs_firstWord = true;
	static T prevWord;

	T currWord;
	T sendWord;

	sendWord.last = 0;
	switch (fsmState)
	{
	case PKG:
		if (!input.empty())
		{
			input.read(currWord);

			if (!rs_firstWord)
			{
				if (offset == 0)
				{
					sendWord = prevWord;
				}
				else
				{
					sendWord.data((W-1)-(8*offset), 0) = prevWord.data((W-1), 8*offset);
					sendWord.data((W-1), W-(8*offset)) = currWord.data((8*offset)-1, 0);

					sendWord.keep((W/8-1)-offset, 0) = prevWord.keep((W/8-1), offset);
					sendWord.keep((W/8-1), (W/8)-offset) = currWord.keep(offset-1, 0);

					sendWord.last = (currWord.keep((W/8-1), offset) == 0);
					//sendWord.dest = currWord.dest;
					// assignDest(sendWord, currWord);
				}//else offset
				output.write(sendWord);
			}

			prevWord = currWord;
			rs_firstWord = false;
			if (currWord.last)
			{
				rs_firstWord = true;
				// rs_firstWord = (offset != 0);
				//rs_writeRemainder = (sendWord.last == 0);
				if (!sendWord.last)
				{
					fsmState = REMAINDER;
				}
			} 
			//}//else offset
		}
		break;
	case REMAINDER:
		if (offset == 0)
		{
			sendWord = prevWord;
		}
		else 
		{
			sendWord.data((W-1)-(8*offset), 0) = prevWord.data((W-1), 8*offset);
			sendWord.data((W-1), W-(8*offset)) = 0;
			sendWord.keep((W/8-1)-offset, 0) = prevWord.keep((W/8-1), offset);
			sendWord.keep((W/8-1), (W/8)-offset) = 0;
			sendWord.last = 1;
		}
		//sendWord.dest = prevWord.dest;
		// assignDest(sendWord, currWord);
		output.write(sendWord);
		fsmState = PKG;
		break;
	}
}

template <typename T, int W, int whatever>
inline void rshiftWordByOctet(	hls::stream<ap_uint<16> >& shiftOffset,
						hls::stream<T>& input,
						hls::stream<T>& output)
{
#pragma HLS inline off
#pragma HLS pipeline II=1 //TODO this has a bug, the bug might come from how it is used

	enum fsmStateType {PKG, REMAINDER};
	static fsmStateType fsmState = PKG;
	static bool rs_firstWord = true;
	static T prevWord;
  	static ap_uint<16> offset;

	T currWord;
	T sendWord;

	sendWord.last = 0;
	switch (fsmState)
	{
	case PKG:
		if (!input.empty() & !shiftOffset.empty())
		{
			input.read(currWord);
      		shiftOffset.read(offset);

			if (!rs_firstWord)
			{
				if (offset == 0)
				{
					sendWord = prevWord;
				}
				else
				{
					sendWord.data((W-1)-(8*offset), 0) = prevWord.data((W-1), 8*offset);
					sendWord.data((W-1), W-(8*offset)) = currWord.data((8*offset)-1, 0);

					sendWord.keep((W/8-1)-offset, 0) = prevWord.keep((W/8-1), offset);
					sendWord.keep((W/8-1), (W/8)-offset) = currWord.keep(offset-1, 0);

					sendWord.last = (currWord.keep((W/8-1), offset) == 0);
					//sendWord.dest = currWord.dest;
					// assignDest(sendWord, currWord);
				}//else offset
				output.write(sendWord);
			}

			prevWord = currWord;
			rs_firstWord = false;
			if (currWord.last)
			{
				rs_firstWord = true;
				// rs_firstWord = (offset != 0);
				//rs_writeRemainder = (sendWord.last == 0);
				if (!sendWord.last)
				{
					fsmState = REMAINDER;
				}
			} 
			//}//else offset
		}
		break;
	case REMAINDER:
		if (offset == 0)
		{
			sendWord = prevWord;
		}
		else 
		{
			sendWord.data((W-1)-(8*offset), 0) = prevWord.data((W-1), 8*offset);
			sendWord.data((W-1), W-(8*offset)) = 0;
			sendWord.keep((W/8-1)-offset, 0) = prevWord.keep((W/8-1), offset);
			sendWord.keep((W/8-1), (W/8)-offset) = 0;
			sendWord.last = 1;
		}
		//sendWord.dest = prevWord.dest;
		// assignDest(sendWord, currWord);
		output.write(sendWord);
		fsmState = PKG;
		break;
	}
}

template <int ind>
void maskDataFromKeep (hls::stream<pkt512 >& inputStream,
                        hls::stream<pkt512 >& outputStream
)
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    static pkt512 inWord;
    static pkt512 outWord;
    if(!inputStream.empty())
    {
        inWord = inputStream.read();
        for (int i = 0; i < 64; i++)
        {
            #pragma HLS UNROLL
            outWord.data(i*8+7, i*8) = (inWord.keep(i,i) == 1) ? inWord.data(i*8+7, i*8) : 0;
        }
        outWord.keep = inWord.keep;
        outWord.last = inWord.last;
        outputStream.write(outWord);
    }
}

template <int ind>
void maskDataFromKeep (hls::stream<net_axis<512> >& inputStream,
                        hls::stream<net_axis<512> >& outputStream
)
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

    static net_axis<512> inWord;
    static net_axis<512> outWord;
    if(!inputStream.empty())
    {
        inWord = inputStream.read();
        for (int i = 0; i < 64; i++)
        {
            #pragma HLS UNROLL
            outWord.data(i*8+7, i*8) = (inWord.keep(i,i) == 1) ? inWord.data(i*8+7, i*8) : 0;
        }
        outWord.keep = inWord.keep;
        outWord.last = inWord.last;
        outputStream.write(outWord);
    }
}

template <class T>
void duplicate_streams_6(	
	hls::stream<T>&	in,
	hls::stream<T>&	out0,
	hls::stream<T>& out1,
	hls::stream<T>& out2,
	hls::stream<T>& out3,
	hls::stream<T>& out4,
	hls::stream<T>& out5
	)
{
	#pragma HLS PIPELINE II=1
	#pragma HLS INLINE off

	if (!in.empty())
	{
		T item = in.read();
		out0.write(item);
		out1.write(item);
		out2.write(item);
		out3.write(item);
		out4.write(item);
		out5.write(item);
	}
}


template <class T>
void duplicate_streams_2(	
	hls::stream<T>&	in,
	hls::stream<T>&	out0,
	hls::stream<T>& out1
	)
{
	#pragma HLS PIPELINE II=1
	#pragma HLS INLINE off

	if (!in.empty())
	{
		T item = in.read();
		out0.write(item);
		out1.write(item);
	}
}

inline ap_uint<64> lenToKeep(ap_uint<6> length)
{
	switch (length)
	{
	case 1:
		return 0x01;
	case 2:
		return 0x03;
	case 3:
		return 0x07;
	case 4:
		return 0x0F;
	case 5:
		return 0x1F;
	case 6:
		return 0x3F;
	case 7:
		return 0x7F;
	case 8:
		return 0xFF;
	case 9:
		return 0x01FF;
	case 10:
		return 0x03FF;
	case 11:
		return 0x07FF;
	case 12:
		return 0x0FFF;
	case 13:
		return 0x1FFF;
	case 14:
		return 0x3FFF;
	case 15:
		return 0x7FFF;
	case 16:
		return 0xFFFF;
	case 17:
		return 0x01FFFF;
	case 18:
		return 0x03FFFF;
	case 19:
		return 0x07FFFF;
	case 20:
		return 0x0FFFFF;
	case 21:
		return 0x1FFFFF;
	case 22:
		return 0x3FFFFF;
	case 23:
		return 0x7FFFFF;
	case 24:
		return 0xFFFFFF;
	case 25:
		return 0x01FFFFFF;
	case 26:
		return 0x03FFFFFF;
	case 27:
		return 0x07FFFFFF;
	case 28:
		return 0x0FFFFFFF;
	case 29:
		return 0x1FFFFFFF;
	case 30:
		return 0x3FFFFFFF;
	case 31:
		return 0x7FFFFFFF;
	case 32:
		return 0xFFFFFFFF;
	case 33:
		return 0x01FFFFFFFF;
	case 34:
		return 0x03FFFFFFFF;
	case 35:
		return 0x07FFFFFFFF;
	case 36:
		return 0x0FFFFFFFFF;
	case 37:
		return 0x1FFFFFFFFF;
	case 38:
		return 0x3FFFFFFFFF;
	case 39:
		return 0x7FFFFFFFFF;
	case 40:
		return 0xFFFFFFFFFF;
	case 41:
		return 0x01FFFFFFFFFF;
	case 42:
		return 0x03FFFFFFFFFF;
	case 43:
		return 0x07FFFFFFFFFF;
	case 44:
		return 0x0FFFFFFFFFFF;
	case 45:
		return 0x1FFFFFFFFFFF;
	case 46:
		return 0x3FFFFFFFFFFF;
	case 47:
		return 0x7FFFFFFFFFFF;
	case 48:
		return 0xFFFFFFFFFFFF;
	case 49:
		return 0x01FFFFFFFFFFFF;
	case 50:
		return 0x03FFFFFFFFFFFF;
	case 51:
		return 0x07FFFFFFFFFFFF;
	case 52:
		return 0x0FFFFFFFFFFFFF;
	case 53:
		return 0x1FFFFFFFFFFFFF;
	case 54:
		return 0x3FFFFFFFFFFFFF;
	case 55:
		return 0x7FFFFFFFFFFFFF;
	case 56:
		return 0xFFFFFFFFFFFFFF;
	case 57:
		return 0x01FFFFFFFFFFFFFF;
	case 58:
		return 0x03FFFFFFFFFFFFFF;
	case 59:
		return 0x07FFFFFFFFFFFFFF;
	case 60:
		return 0x0FFFFFFFFFFFFFFF;
	case 61:
		return 0x1FFFFFFFFFFFFFFF;
	case 62:
		return 0x3FFFFFFFFFFFFFFF;
	case 63:
		return 0x7FFFFFFFFFFFFFFF;
	default:
		return 0xFFFFFFFFFFFFFFFF;
	}//switch
}

