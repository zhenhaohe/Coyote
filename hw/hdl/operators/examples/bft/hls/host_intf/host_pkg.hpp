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
#include <stdint.h>

#include "ap_int.h"


#define VADDR_BITS          48
#define LEN_BITS            28
#define DEST_BITS           4
#define PID_BITS            6
#define RID_BITS            4


//
// Structs
//
// DMA interfaces
struct reqIntf {
    ap_uint<VADDR_BITS> vaddr;
    ap_uint<LEN_BITS> len;
    ap_uint<1> strm;
    ap_uint<1> sync;
    ap_uint<1> ctl;
    ap_uint<1> host;
    ap_uint<DEST_BITS> dst;
    ap_uint<PID_BITS> pid;
    ap_uint<RID_BITS> rid;

    reqIntf()
        : vaddr(0), len(0), strm(0), sync(0), ctl(0), host(0), dst(0), pid(0), rid(0) {}
    
    reqIntf(ap_uint<94> req)
        : vaddr(req.range(47,0)), len(req.range(75,48)), strm(req.range(76,76)), sync(req.range(77,77)), ctl(req.range(78,78)), host(req.range(79,79)), dst(req.range(83,80)), pid(req.range(89,84)), rid(req.range(93,90)) {}

    reqIntf(ap_uint<VADDR_BITS> vaddr, ap_uint<LEN_BITS> len, ap_uint<1> strm, ap_uint<1> sync, 
            ap_uint<1> ctl, ap_uint<1> host, ap_uint<DEST_BITS> dst, ap_uint<PID_BITS> pid, ap_uint<RID_BITS> rid)
        : vaddr(vaddr), len(len), strm(strm), sync(sync), ctl(ctl), host(host), dst(dst), pid(pid), rid(rid) {}
};