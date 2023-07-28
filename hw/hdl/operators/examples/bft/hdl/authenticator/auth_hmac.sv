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
`timescale 1ns / 1ps
import lynxTypes::*;
import bftTypes::*;

// auth hmac
module auth_hmac 
#( 
    parameter integer PIPE_INDEX = 0
)
(
    
    metaIntf.s                  keyStrm, //32 bits
    metaIntf.s                  msgStrm, //32 bits
    metaIntf.s                  lenStrm, //64 bits
    
    metaIntf.m                  hshStrm, //256 bits

    // Clock and reset
    input  wire                 aclk,
    input  wire[0:0]            aresetn

);


metaIntf #(.STYPE(logic[8-1:0])) eHshStrm();
metaIntf #(.STYPE(logic[8-1:0])) eLenStrm();
metaIntf #(.STYPE(logic[64-1:0])) lenStrm_s1();

hmac_eLen_handler_ip hmac_eLen_handler_inst(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .len_strm_in_TDATA(lenStrm.data),
    .len_strm_in_TVALID(lenStrm.valid),
    .len_strm_in_TREADY(lenStrm.ready),
    .len_strm_out_TDATA(lenStrm_s1.data),
    .len_strm_out_TVALID(lenStrm_s1.valid),
    .len_strm_out_TREADY(lenStrm_s1.ready),
    .end_len_strm_out_TDATA(eLenStrm.data),
    .end_len_strm_out_TVALID(eLenStrm.valid),
    .end_len_strm_out_TREADY(eLenStrm.ready)
);

hmac_sha256 hmac_sha256(
    .ap_clk(aclk),
    .ap_rst_n(aresetn),
    .keyStrm_TDATA(keyStrm.data),
    .keyStrm_TVALID(keyStrm.valid),
    .keyStrm_TREADY(keyStrm.ready),
    .msgStrm_TDATA(msgStrm.data),
    .msgStrm_TVALID(msgStrm.valid),
    .msgStrm_TREADY(msgStrm.ready),
    .lenStrm_TDATA(lenStrm_s1.data),
    .lenStrm_TVALID(lenStrm_s1.valid),
    .lenStrm_TREADY(lenStrm_s1.ready),
    .eLenStrm_TDATA(eLenStrm.data),
    .eLenStrm_TVALID(eLenStrm.valid),
    .eLenStrm_TREADY(eLenStrm.ready),
    .hshStrm_TDATA(hshStrm.data),
    .hshStrm_TVALID(hshStrm.valid),
    .hshStrm_TREADY(hshStrm.ready),
    .eHshStrm_TDATA(eHshStrm.data),
    .eHshStrm_TVALID(eHshStrm.valid),
    .eHshStrm_TREADY(eHshStrm.ready)
);

assign eHshStrm.ready = 1'b1;

`ifdef DEBUG_AUTH_HMAC

    logic [63:0] execution_cycles;

    always @( posedge aclk ) begin 
        if (~aresetn) begin
            execution_cycles <= '0;
        end
        else begin
            execution_cycles <= execution_cycles + 1'b1;
        end
    end
    
    if (PIPE_INDEX == 0) begin
        ila_auth_hmac ila_auth_hmac
        (
            .clk(aclk), // input wire clk
            .probe0(msgStrm.valid), //1
            .probe1(msgStrm.ready), //1
            .probe2(eHshStrm.ready), //1
            .probe3(eHshStrm.data), //1
            .probe4(keyStrm.valid), //1
            .probe5(keyStrm.ready), //1
            .probe6(lenStrm_s1.valid), //1
            .probe7(lenStrm_s1.ready), //1
            .probe8(eLenStrm.valid), //1
            .probe9(eLenStrm.data), //1
            .probe10(eLenStrm.ready), //1
            .probe11(hshStrm.valid), //1
            .probe12(hshStrm.ready), //1
            .probe13(hshStrm.data), //256
            .probe14(msgStrm.data), //32
            .probe15(lenStrm_s1.data), //64
            .probe16(keyStrm.data), //32
            .probe17(eHshStrm.valid), // 1
            .probe18(execution_cycles) // 64
        );
    end 
`endif 

endmodule
