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

// TODO: might need to add inflight controller
#define OPT_SMALL_MSG

typedef ap_axiu<DWIDTH512, 0, 0, 0> pkt512;
typedef ap_axiu<DWIDTH256, 0, 0, 0> pkt256;
typedef ap_axiu<DWIDTH128, 0, 0, 0> pkt128;
typedef ap_axiu<DWIDTH64, 0, 0, 0> pkt64;
typedef ap_axiu<DWIDTH32, 0, 0, 0> pkt32;
typedef ap_axiu<DWIDTH16, 0, 0, 0> pkt16;
typedef ap_axiu<DWIDTH8, 0, 0, 0> pkt8;


#ifdef OPT_SMALL_MSG


void tcp_txCmdHandler(
          hls::stream<ap_uint<64> >& cmd_txHandler,
          hls::stream<ap_uint<32> >& m_axis_tcp_tx_meta, 
          hls::stream<ap_uint<64> >& s_axis_tcp_tx_status,
          hls::stream<ap_uint<64> >& internalTxMeta,
          ap_uint<32> maxPkgWord
          )
{
     #pragma HLS PIPELINE II=1
     #pragma HLS INLINE off

     enum txCmdHandlerStateType {WAIT_CMD, CHECK_REQ, INTERNAL_META};
     static txCmdHandlerStateType txCmdHandlerState = WAIT_CMD;

     static ap_uint<32> sessionID;
     static ap_uint<32> expectedTxByteCnt;

     static ap_uint<16> length;
     static ap_uint<16> remaining_space;
     static ap_uint<8> error;
     static ap_uint<32> currentPkgWord = 0;

     static ap_uint<32> sentByteCnt = 0;


     static ap_uint<32> tx_meta_pkt;


     switch(txCmdHandlerState)
	{
		case WAIT_CMD:
			if (!cmd_txHandler.empty())
			{
				ap_uint<64> cmd = cmd_txHandler.read();
				sessionID = cmd(31,0);
				expectedTxByteCnt = cmd(63,32);

                    tx_meta_pkt(15,0) = sessionID;

				if (maxPkgWord*(512/8) > expectedTxByteCnt)
					tx_meta_pkt(31,16) = expectedTxByteCnt;
				else
					tx_meta_pkt(31,16) = maxPkgWord*(512/8);

				m_axis_tcp_tx_meta.write(tx_meta_pkt);

                    txCmdHandlerState = CHECK_REQ;
			}
		break;
		case CHECK_REQ:
			if (!s_axis_tcp_tx_status.empty())
               {
                    ap_uint<64> txStatus_pkt = s_axis_tcp_tx_status.read();
                    sessionID = txStatus_pkt(15,0);
                    length = txStatus_pkt(31,16);
                    remaining_space = txStatus_pkt(61,32);
                    error = txStatus_pkt(63,62);
                    currentPkgWord = (length + (512/8) -1 ) >> 6; //current packet word length

                    //if no error, perpare the tx meta of the next packet
                    if (error == 0)
                    {
                         sentByteCnt = sentByteCnt + length;

                         if (sentByteCnt < expectedTxByteCnt)
                         {
                              tx_meta_pkt(15,0) = sessionID;

                              if (sentByteCnt + maxPkgWord*64 < expectedTxByteCnt )
                              {
                            	  tx_meta_pkt(31,16) = maxPkgWord*(512/8);
                              }
                              else
                              {
                                  tx_meta_pkt(31,16) = expectedTxByteCnt - sentByteCnt;
                              }
                              
                              m_axis_tcp_tx_meta.write(tx_meta_pkt);
                         }
  					txCmdHandlerState = INTERNAL_META;
                    }
                    //if error, resend the tx meta of current packet 
                    else
                    {
                         //Check if connection  was torn down
                         if (error == 1)
                         {
                              // std::cout << "Connection was torn down. " << sessionID << std::endl;
                         }
                         else
                         {
                              tx_meta_pkt(15,0) = sessionID;
                              tx_meta_pkt(31,16) = length;
                              m_axis_tcp_tx_meta.write(tx_meta_pkt);
                         }
                    }
               }
		break;
		case INTERNAL_META:
               ap_uint<64> internalMeta;
               internalMeta(31,0) = sessionID;
               internalMeta(63,32) = currentPkgWord;
               internalTxMeta.write(internalMeta);
               if (sentByteCnt >= expectedTxByteCnt)
               {
                    sentByteCnt = 0;
                    currentPkgWord = 0;
                    txCmdHandlerState = WAIT_CMD;
               }
               else
               {
                    txCmdHandlerState = CHECK_REQ;
               }
		break;
	}

}


void tcp_txDataHandler(
     hls::stream<pkt512 >& s_data_in,
     hls::stream<ap_uint<64> >& internalTxMeta,
     hls::stream<pkt512>& m_axis_tcp_tx_data
)
{
     #pragma HLS PIPELINE II=1
     #pragma HLS INLINE off

     enum txDataHandlerStateType {WAIT_CMD, WRITE_PKG};
     static txDataHandlerStateType txDataHandlerState = WAIT_CMD;

     static ap_uint<32> sessionID;

     static ap_uint<32> currentPkgWord = 0;
     static ap_uint<32> wordCnt = 0;

     switch(txDataHandlerState)
	{
		case WAIT_CMD:
			if (!internalTxMeta.empty() & !s_data_in.empty())
			{
				ap_uint<64> cmd = internalTxMeta.read();
				sessionID = cmd(31,0);
				currentPkgWord = cmd(63,32);

				txDataHandlerState = WRITE_PKG;
			}
		break;
		case WRITE_PKG:
			wordCnt ++;
			ap_axiu<DWIDTH512, 0, 0, 0> currWord = s_data_in.read();
			ap_axiu<DWIDTH512, 0, 0, 0> currPkt;
               currPkt.data = currWord.data;
               currPkt.keep = currWord.keep;
               currPkt.last = (wordCnt == currentPkgWord);
               m_axis_tcp_tx_data.write(currPkt);
               if (wordCnt == currentPkgWord)
               {
                    wordCnt = 0;
                    txDataHandlerState = WAIT_CMD;
               }
		break;
	}

}


void tcp_txHandler(
               hls::stream<pkt512 >& s_data_in,
               hls::stream<ap_uint<64> >& cmd_txHandler,
               hls::stream<ap_uint<32> >& m_axis_tcp_tx_meta, 
               hls::stream<pkt512>& m_axis_tcp_tx_data, 
               hls::stream<ap_uint<64> >& s_axis_tcp_tx_status,
               ap_uint<32> maxPkgWord
                )
{
#pragma HLS INTERFACE axis register  port=s_data_in
#pragma HLS INTERFACE axis register  port=cmd_txHandler
#pragma HLS INTERFACE axis register  port=m_axis_tcp_tx_meta
#pragma HLS INTERFACE axis register  port=m_axis_tcp_tx_data
#pragma HLS INTERFACE axis register  port=s_axis_tcp_tx_status
#if defined( __VITIS_HLS__)
    #pragma HLS INTERFACE ap_none register port=maxPkgWord
#else
    #pragma HLS INTERFACE ap_stable register port=maxPkgWord
#endif
#pragma HLS INTERFACE ap_ctrl_none port=return
#pragma HLS DATAFLOW disable_start_propagation
// #pragma HLS PIPELINE II=1
// #pragma HLS INLINE off

     static hls::stream<ap_uint<64> > internalTxMeta;
     #pragma HLS stream variable=internalTxMeta depth=128

     tcp_txCmdHandler(
          cmd_txHandler,
          m_axis_tcp_tx_meta, 
          s_axis_tcp_tx_status,
          internalTxMeta,
          maxPkgWord
          );

	tcp_txDataHandler(s_data_in,
                    internalTxMeta,
                    m_axis_tcp_tx_data);

}


#else
void tcp_txHandler(
               hls::stream<pkt512 >& s_data_in,
               hls::stream<ap_uint<64> >& cmd_txHandler,
               hls::stream<ap_uint<32> >& m_axis_tcp_tx_meta, 
               hls::stream<pkt512>& m_axis_tcp_tx_data, 
               hls::stream<ap_uint<64> >& s_axis_tcp_tx_status,
               ap_uint<32> maxPkgWord
                )
{
#pragma HLS INTERFACE axis register  port=s_data_in
#pragma HLS INTERFACE axis register  port=cmd_txHandler
#pragma HLS INTERFACE axis register  port=m_axis_tcp_tx_meta
#pragma HLS INTERFACE axis register  port=m_axis_tcp_tx_data
#pragma HLS INTERFACE axis register  port=s_axis_tcp_tx_status
#if defined( __VITIS_HLS__)
    #pragma HLS INTERFACE ap_none register port=maxPkgWord
#else
    #pragma HLS INTERFACE ap_stable register port=maxPkgWord
#endif
#pragma HLS INTERFACE ap_ctrl_none port=return

#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

	enum txHandlerStateType {WAIT_CMD, WAIT_FIRST_DATA, CHECK_REQ, WRITE_PKG};
     static txHandlerStateType txHandlerState = WAIT_CMD;

     static ap_uint<32> sessionID;
     static ap_uint<32> expectedTxByteCnt;
     // static ap_uint<32> maxPkgWord;

     static ap_uint<16> length;
     static ap_uint<16> remaining_space;
     static ap_uint<8> error;
     static ap_uint<32> currentPkgWord = 0;
     static ap_uint<32> wordCnt = 0;

     static ap_uint<32> sentByteCnt = 0;


     static ap_uint<32> tx_meta_pkt;

	switch(txHandlerState)
	{
		case WAIT_CMD:
			if (!cmd_txHandler.empty())
			{
				ap_uint<64> cmd = cmd_txHandler.read();
				sessionID = cmd(31,0);
				expectedTxByteCnt = cmd(63,32);
				// maxPkgWord = cmd(95,64);

				txHandlerState = WAIT_FIRST_DATA;
			}
		break;
          case WAIT_FIRST_DATA:
               if(!s_data_in.empty())
               {
                    tx_meta_pkt(15,0) = sessionID;

				if (maxPkgWord*(512/8) > expectedTxByteCnt)
					tx_meta_pkt(31,16) = expectedTxByteCnt;
				else
					tx_meta_pkt(31,16) = maxPkgWord*(512/8);

				m_axis_tcp_tx_meta.write(tx_meta_pkt);

                    txHandlerState = CHECK_REQ;
               }
          break;
		case CHECK_REQ:
			if (!s_axis_tcp_tx_status.empty())
               {
                    ap_uint<64> txStatus_pkt = s_axis_tcp_tx_status.read();
                    sessionID = txStatus_pkt(15,0);
                    length = txStatus_pkt(31,16);
                    remaining_space = txStatus_pkt(61,32);
                    error = txStatus_pkt(63,62);
                    currentPkgWord = (length + (512/8) -1 ) >> 6; //current packet word length

                    //if no error, perpare the tx meta of the next packet
                    if (error == 0)
                    {
                         sentByteCnt = sentByteCnt + length;

                         if (sentByteCnt < expectedTxByteCnt)
                         {
                              tx_meta_pkt(15,0) = sessionID;

                              if (sentByteCnt + maxPkgWord*64 < expectedTxByteCnt )
                              {
                            	  tx_meta_pkt(31,16) = maxPkgWord*(512/8);
                            	  // currentPkgWord = maxPkgWord;
                              }
                              else
                              {
                                  tx_meta_pkt(31,16) = expectedTxByteCnt - sentByteCnt;
                                  // currentPkgWord = (expectedTxByteCnt - sentByteCnt)>>6;
                              }
                              
                              m_axis_tcp_tx_meta.write(tx_meta_pkt);
                        }
  						txHandlerState = WRITE_PKG;
                    }
                    //if error, resend the tx meta of current packet 
                    else
                    {
                         //Check if connection  was torn down
                         if (error == 1)
                         {
                              // std::cout << "Connection was torn down. " << sessionID << std::endl;
                         }
                         else
                         {
                              tx_meta_pkt(15,0) = sessionID;
                              tx_meta_pkt(31,16) = length;
                              m_axis_tcp_tx_meta.write(tx_meta_pkt);
                         }
                    }
               }
		break;
		case WRITE_PKG:
			wordCnt ++;
			ap_axiu<DWIDTH512, 0, 0, 0> currWord = s_data_in.read();
			ap_axiu<DWIDTH512, 0, 0, 0> currPkt;
               currPkt.data = currWord.data;
               currPkt.keep = currWord.keep;
               currPkt.last = (wordCnt == currentPkgWord);
               m_axis_tcp_tx_data.write(currPkt);
               if (wordCnt == currentPkgWord)
               {
                    wordCnt = 0;
                    if (sentByteCnt >= expectedTxByteCnt)
                    {
                         sentByteCnt = 0;
                         currentPkgWord = 0;
                         txHandlerState = WAIT_CMD;
                    }
                    else
                    {
                         txHandlerState = CHECK_REQ;
                    }
               }
		break;
	}

}
#endif