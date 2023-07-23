#include <iostream>
#include <fcntl.h>
#include <unistd.h>
#include <fstream>
#include <malloc.h>
#include <time.h> 
#include <sys/time.h>  
#include <chrono>
#include <iomanip>
#include <fcntl.h>
#include <vector>

#include "bft.hpp"

using namespace std::chrono;

void BFT_MSG::DeserializeFromArray(void* array){

    uint32_t* offset_ptr = static_cast<uint32_t*>(array);

    if (offset_ptr == nullptr) {
        std::cerr<<"NULL Pointer"<<std::endl;
        return;
    }

    hdr.cmdID = offset_ptr[0];
    hdr.cmdLen = offset_ptr[1];
    hdr.dst = offset_ptr[2];
    hdr.src = offset_ptr[3];
    hdr.tag = offset_ptr[4];
    hdr.dataLen = offset_ptr[5];
    hdr.msgID = offset_ptr[6];
    hdr.msgType = offset_ptr[7];
    hdr.epochID = offset_ptr[8];
    hdr.totalRank = offset_ptr[9];

    if (hdr.dataLen > 0) {
        payload = new char[hdr.dataLen];
        char* payload_ptr_char = reinterpret_cast<char*>(offset_ptr + 10);

        for (uint32_t i = 0; i < hdr.dataLen; i++) {
            *(reinterpret_cast<char*>(payload) + i) = *(payload_ptr_char + i);
        }
    }
}


void BFT_MSG::SerializeToArray(void* array){
    uint32_t* offset_ptr = (uint32_t*) array;

    *offset_ptr = hdr.cmdID;
    *(offset_ptr+1) = hdr.cmdLen;
    *(offset_ptr+2) = hdr.dst;
    *(offset_ptr+3) = hdr.src;
    *(offset_ptr+4) = hdr.tag;
    *(offset_ptr+5) = hdr.dataLen;
    *(offset_ptr+6) = hdr.msgID;
    *(offset_ptr+7) = hdr.msgType;
    *(offset_ptr+8) = hdr.epochID;
    *(offset_ptr+9) = hdr.totalRank;
    *(offset_ptr+10) = 0;
    *(offset_ptr+11) = 0;
    *(offset_ptr+12) = 0;
    *(offset_ptr+13) = 0;
    *(offset_ptr+14) = 0;
    *(offset_ptr+15) = 0;

    char* offset_ptr_char = reinterpret_cast<char*> (offset_ptr+16);
    char* payload_ptr_char = reinterpret_cast<char*> (payload);

    for (uint32_t i = 0; i < hdr.dataLen; i++)
    {
        *(offset_ptr_char+i) = *(payload_ptr_char+i);
    }
}