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

#define RATE_CONTROL

typedef ap_axiu<DWIDTH512, 0, 0, 0> pkt512;
typedef ap_axiu<DWIDTH256, 0, 0, 0> pkt256;
typedef ap_axiu<DWIDTH128, 0, 0, 0> pkt128;
typedef ap_axiu<DWIDTH64, 0, 0, 0> pkt64;
typedef ap_axiu<DWIDTH32, 0, 0, 0> pkt32;
typedef ap_axiu<DWIDTH16, 0, 0, 0> pkt16;
typedef ap_axiu<DWIDTH8, 0, 0, 0> pkt8;


#ifdef RATE_CONTROL
void inflightReadHandler(hls::stream<bool>& inflightReadCntReq,
                         hls::stream<ap_uint<32> >& inflightReadCntRsp,
                         hls::stream<bool>& incrCntReq,
                         hls::stream<bool>& decrCntReq )
{
#pragma HLS INLINE off
#pragma HLS PIPELINE II=1

     static ap_uint<32> inflightCnt = 0;
     #pragma HLS DEPENDENCE variable=inflightCnt inter false

     if (!decrCntReq.empty() & incrCntReq.empty())
     {
          decrCntReq.read();
          if (inflightCnt > 0)
               inflightCnt = inflightCnt - 1;
     }
     else if (!incrCntReq.empty() & decrCntReq.empty())
     {
          incrCntReq.read();
          inflightCnt = inflightCnt + 1;
     }
     else if (!decrCntReq.empty() & !incrCntReq.empty())
     {
          decrCntReq.read();
          incrCntReq.read();
     }

     if (!inflightReadCntReq.empty())
     {
          inflightReadCntReq.read();
          inflightReadCntRsp.write(inflightCnt);
     }
}

void requestFSM(hls::stream<ap_uint<128> >& s_axis_tcp_notification, 
               hls::stream<ap_uint<32> >& m_axis_tcp_read_pkg,
               hls::stream<ap_uint<32> >& inflightReadReq,
               hls::stream<bool>& inflightReadCntReq,
               hls::stream<ap_uint<32> >& inflightReadCntRsp,
               hls::stream<bool>& incrCntReq)
{
     #pragma HLS PIPELINE II=1
     #pragma HLS INLINE off

     enum requestFsmStateType {WAIT_NOTI, CHECK_IN_FLIGHT, BACK_OFF, REQUEST};
     static requestFsmStateType  requestFsmState = WAIT_NOTI;

     static ap_uint<8> counter = 0;

     switch(requestFsmState)
     {
     case WAIT_NOTI:
          if (!s_axis_tcp_notification.empty())
          {
               bool readReq = true;
               inflightReadCntReq.write(readReq);
               requestFsmState = CHECK_IN_FLIGHT;
          }
     break;
     case CHECK_IN_FLIGHT:
          if (!inflightReadCntRsp.empty())
          {
               ap_uint<32> inflightCnt = inflightReadCntRsp.read();
               if (inflightCnt < 8)
               {
                    requestFsmState = REQUEST;
               }
               else
               {
                    requestFsmState = BACK_OFF;
                    // cout<<"Enter BACK_OFF"<<endl;
               }
          }
     break;
     case BACK_OFF:
          if (counter == 8)
          {
               counter = 0;
               requestFsmState = WAIT_NOTI;
          }
          else 
          {
               counter = counter + 1;
          }
     break;
     case REQUEST:
          ap_uint<128> tcp_notification_pkt = s_axis_tcp_notification.read();
          ap_uint<16> sessionID = tcp_notification_pkt(15,0);
          ap_uint<16> length = tcp_notification_pkt(31,16);
          ap_uint<32> ipAddress = tcp_notification_pkt(63,32);
          ap_uint<16> dstPort = tcp_notification_pkt(79,64);
          ap_uint<1> closed = tcp_notification_pkt(80,80);

          if (length!=0)
          {
               ap_uint<32> readRequest_pkt;
               readRequest_pkt(15,0) = sessionID;
               readRequest_pkt(31,16) = length;
               m_axis_tcp_read_pkg.write(readRequest_pkt);
               inflightReadReq.write(readRequest_pkt);
               bool incrReq = true;
               incrCntReq.write(incrReq);
          }
          requestFsmState = WAIT_NOTI;

     break;
     }
}

void consumeFSM(hls::stream<ap_uint<16> >& s_axis_tcp_rx_meta, 
               hls::stream<ap_uint<32> >& inflightReadReq,
               hls::stream<pkt512>& s_axis_tcp_rx_data,
               hls::stream<pkt512 >& s_data_out,
               hls::stream<ap_uint<64> >& s_meta_out,
               hls::stream<bool>& decrCntReq
               )
{
#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

     static pkt512 currWord;
     enum consumeFsmStateType {WAIT_PKG, CONSUME};
     static consumeFsmStateType  serverFsmState = WAIT_PKG;

     switch (serverFsmState)
     {
     case WAIT_PKG:
          if (!s_axis_tcp_rx_meta.empty() && !s_axis_tcp_rx_data.empty() && !inflightReadReq.empty())
          {
               ap_uint<16> session = s_axis_tcp_rx_meta.read();
               ap_uint<32> readReq = inflightReadReq.read();
               ap_uint<64> meta_out;
               meta_out(31,0) = session;
               meta_out(63,32) = readReq(31,16); //length
               s_meta_out.write(meta_out);

               pkt512 receiveWord = s_axis_tcp_rx_data.read();
               currWord.data = receiveWord.data;
               currWord.keep = receiveWord.keep;
               currWord.last = receiveWord.last;
               s_data_out.write(currWord);
               if (!receiveWord.last)
               {
                    serverFsmState = CONSUME;
               }
               else if (receiveWord.last)
               {
                    bool decrReq = true;
                    decrCntReq.write(decrReq);
               }
          }
          break;
     case CONSUME:
          if (!s_axis_tcp_rx_data.empty())
          {
               pkt512 receiveWord = s_axis_tcp_rx_data.read();
               currWord.data = receiveWord.data;
               currWord.keep = receiveWord.keep;
               currWord.last = receiveWord.last;
               s_data_out.write(currWord);
               if (receiveWord.last)
               {
                    bool decrReq = true;
                    decrCntReq.write(decrReq);
                    serverFsmState = WAIT_PKG;
               }
          }
          break;
     }
}

void tcp_rxHandler(   
               hls::stream<ap_uint<128> >& s_axis_tcp_notification, 
               hls::stream<ap_uint<32> >& m_axis_tcp_read_pkg,
               hls::stream<ap_uint<16> >& s_axis_tcp_rx_meta, 
               hls::stream<pkt512>& s_axis_tcp_rx_data,
               hls::stream<pkt512 >& s_data_out,
               hls::stream<ap_uint<64> >& s_meta_out
                )
{

#pragma HLS INTERFACE axis register  port=s_axis_tcp_notification
#pragma HLS INTERFACE axis register  port=m_axis_tcp_read_pkg
#pragma HLS INTERFACE axis register  port=s_axis_tcp_rx_meta
#pragma HLS INTERFACE axis register  port=s_axis_tcp_rx_data
#pragma HLS INTERFACE axis register  port=s_data_out
#pragma HLS INTERFACE axis register  port=s_meta_out
#pragma HLS INTERFACE ap_ctrl_none port=return
#pragma HLS DATAFLOW disable_start_propagation
// #pragma HLS PIPELINE II=1
// #pragma HLS INLINE

     static hls::stream<ap_uint<32> > inflightReadReq;
     static hls::stream<bool> inflightReadCntReq;
     static hls::stream<ap_uint<32> > inflightReadCntRsp;
     static hls::stream<bool> incrCntReq;
     static hls::stream<bool> decrCntReq;
     #pragma HLS stream variable=inflightReadReq depth=16
     #pragma HLS stream variable=inflightReadCntReq depth=4
     #pragma HLS stream variable=inflightReadCntRsp depth=4
     #pragma HLS stream variable=incrCntReq depth=4
     #pragma HLS stream variable=decrCntReq depth=4

     
     requestFSM(s_axis_tcp_notification, 
               m_axis_tcp_read_pkg,
               inflightReadReq,
               inflightReadCntReq,
               inflightReadCntRsp,
               incrCntReq);

     inflightReadHandler(inflightReadCntReq,
                         inflightReadCntRsp,
                         incrCntReq,
                         decrCntReq );


     consumeFSM(s_axis_tcp_rx_meta, 
               inflightReadReq,
               s_axis_tcp_rx_data,
               s_data_out,
               s_meta_out,
               decrCntReq
               );

}

#else
void tcp_rxHandler(   
               hls::stream<pkt128>& s_axis_tcp_notification, 
               hls::stream<pkt32>& m_axis_tcp_read_pkg,
               hls::stream<pkt16>& s_axis_tcp_rx_meta, 
               hls::stream<pkt512>& s_axis_tcp_rx_data,
               hls::stream<pkt512 >& s_data_out
                )
{

#pragma HLS INTERFACE axis register both port=s_axis_tcp_notification
#pragma HLS INTERFACE axis register both port=m_axis_tcp_read_pkg
#pragma HLS INTERFACE axis register both port=s_axis_tcp_rx_meta
#pragma HLS INTERFACE axis register both port=s_axis_tcp_rx_data
#pragma HLS INTERFACE axis register both port=s_data_out
#pragma HLS INTERFACE ap_ctrl_none port=return

#pragma HLS PIPELINE II=1
#pragma HLS INLINE off

     pkt512 currWord;
     enum consumeFsmStateType {WAIT_PKG, CONSUME};
     static consumeFsmStateType  serverFsmState = WAIT_PKG;

     if (!s_axis_tcp_notification.empty())
     {

          pkt128 tcp_notification_pkt = s_axis_tcp_notification.read();
          ap_uint<16> sessionID = tcp_notification_pkt.data(15,0);
          ap_uint<16> length = tcp_notification_pkt.data(31,16);
          ap_uint<32> ipAddress = tcp_notification_pkt.data(63,32);
          ap_uint<16> dstPort = tcp_notification_pkt.data(79,64);
          ap_uint<1> closed = tcp_notification_pkt.data(80,80);

          // cout<<"notification session "<<sessionID<<" length "<<length<<endl;

          if (length!=0)
          {
               pkt32 readRequest_pkt;
               readRequest_pkt.data(15,0) = sessionID;
               readRequest_pkt.data(31,16) = length;
               m_axis_tcp_read_pkg.write(readRequest_pkt);
          }
     }


     switch (serverFsmState)
     {
     case WAIT_PKG:
          if (!s_axis_tcp_rx_meta.empty() && !s_axis_tcp_rx_data.empty())
          {
               s_axis_tcp_rx_meta.read();
               pkt512 receiveWord = s_axis_tcp_rx_data.read();
               currWord.data = receiveWord.data;
               currWord.keep = receiveWord.keep;
               currWord.last = receiveWord.last;
               s_data_out.write(currWord);
               if (!receiveWord.last)
               {
                    serverFsmState = CONSUME;
               }
          }
          break;
     case CONSUME:
          if (!s_axis_tcp_rx_data.empty())
          {
               pkt512 receiveWord = s_axis_tcp_rx_data.read();
               currWord.data = receiveWord.data;
               currWord.keep = receiveWord.keep;
               currWord.last = receiveWord.last;
               s_data_out.write(currWord);
               if (receiveWord.last)
               {
                    serverFsmState = WAIT_PKG;
               }
          }
          break;
     }
}
#endif