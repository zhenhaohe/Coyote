#pragma once

#include <iostream>
#include <queue>
#include <cstdint>
#include <vector>

#define TIMEOUT_US 10
#define BUF_HDR_SIZE 64
#define NUM_RX_BUF 2
#define RX_BUF_SIZE 33554432

struct bufBatchHdr {
    unsigned int total_bytes;
    unsigned int num_msg;
    uint16_t msg_len [24];
    unsigned int seq;
    unsigned int buf_full;

    // Deserialize function to populate the struct from char* data
    void deserialize(char* data) {
        std::memcpy(&total_bytes, data, sizeof(unsigned int));
        std::memcpy(&num_msg, data + sizeof(unsigned int), sizeof(unsigned int));
        std::memcpy(&msg_len, data + 2 * sizeof(unsigned int), sizeof(uint16_t) * 24);
        std::memcpy(&seq, data + 2 * sizeof(unsigned int) + sizeof(uint16_t) * 24, sizeof(unsigned int));
        std::memcpy(&buf_full, data + 2 * sizeof(unsigned int) + sizeof(uint16_t) * 24 + sizeof(unsigned int), sizeof(unsigned int));
    }

    // Function to print the header fields
    void printHeader() const {
        std::cerr << "total_bytes: " << total_bytes << ", "
                  << "num_msg: " << num_msg << ", "
                  << "msg_len: [";
        for (int i = 0; i < 24; ++i) {
            std::cerr << msg_len[i];
            if (i != 23) {
                std::cerr << ", ";
            }
        }
        std::cerr << "], "
                  << "seq: " << seq << ", "
                  << "buf_full: " << buf_full << std::endl;
    }
};

struct buf_t {
    void* addr;
    unsigned int size;
    unsigned int head_offset;
    unsigned int tail_offset;

    // Constructor to initialize member variables to zero or NULL
    buf_t() : addr(nullptr), size(0), head_offset(0), tail_offset(0) {}

    // Getter function for the head pointer
    void* getHeadPointer() {
        return static_cast<char*>(addr) + head_offset;
    }

    // Getter function for the head pointer
    void* getTailPointer() {
        return static_cast<char*>(addr) + tail_offset;
    }
};

struct rxHandler_t {
    unsigned int curr_transfer_cnt;
    std::queue<buf_t> buf_queue;

    // Constructor
    rxHandler_t() : curr_transfer_cnt(0) {}

    // Getter function to retrieve a reference to the first buf
    buf_t & curr_buf() {
        return buf_queue.front();
    }
};

// struct txHandler_t {
//     unsigned int curr_transfer_cnt;
//     std::queue<buf_t> buf_queue;

//     // Constructor
//     txHandler_t() : curr_transfer_cnt(0) {}

//     // Getter function to retrieve a reference to the first buf
//     buf_t & curr_buf() {
//         return buf_queue.front();
//     }
// };