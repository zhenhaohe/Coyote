#pragma once

#include <cstdint>
#include <vector>

#define CMD_LEN 64

#define NET_OFFLOAD 0
#define AUTH_OFFLOAD 1

struct bft_msg_hdr
{
    uint32_t cmdID; // specifier of different communication primitive
    uint32_t cmdLen; // total byte len of compulsory & optional cmd fields
    uint32_t dst; // either dst rank or communicator ID depends on primitive
    uint32_t src; // src rank
    uint32_t tag; // tag, reserved
    uint32_t dataLen; //total byte len of data to each primitive
    uint32_t msgID;
    uint32_t msgType;
    uint32_t epochID;
    uint32_t totalRank;
    uint32_t clientID;
    uint32_t timestamp;

    // Constructor
    bft_msg_hdr(uint32_t cmdID = 0, uint32_t dst = 0, uint32_t src = 0,
                uint32_t tag = 0, uint32_t dataLen = 0, uint32_t msgID = 0, uint32_t msgType = 0,
                uint32_t epochID = 0, uint32_t totalRank = 0, uint32_t clientID = 0,
                uint32_t timestamp = 0)
        : cmdID(cmdID), cmdLen(CMD_LEN), dst(dst), src(src), tag(tag), dataLen(dataLen),
          msgID(msgID), msgType(msgType), epochID(epochID), totalRank(totalRank),
          clientID(clientID), timestamp(timestamp)
    {}
};

class BFT_MSG {
private:
    bft_msg_hdr hdr;
    void* payload;

public: 
	BFT_MSG() : hdr{}, payload(nullptr) {} 
	BFT_MSG(bft_msg_hdr hdr, void* payload): hdr(hdr), payload(payload){};
	~BFT_MSG(){
        delete[] reinterpret_cast<char*>(payload);
    };

    // Getter methods for hdr fields
    uint32_t getCmdID() const { return hdr.cmdID; }
    uint32_t getCmdLen() const { return hdr.cmdLen; }
    uint32_t getDst() const { return hdr.dst; }
    uint32_t getSrc() const { return hdr.src; }
    uint32_t getTag() const { return hdr.tag; }
    uint32_t getDataLen() const { return hdr.dataLen; }
    uint32_t getMsgID() const { return hdr.msgID; }
    uint32_t getMsgType() const { return hdr.msgType; }
    uint32_t getEpochID() const { return hdr.epochID; }
    uint32_t getTotalRank() const { return hdr.totalRank; }

    // Setter methods for hdr fields
    void setCmdID(uint32_t value) { hdr.cmdID = value; }
    void setCmdLen(uint32_t value) { hdr.cmdLen = value; }
    void setDst(uint32_t value) { hdr.dst = value; }
    void setSrc(uint32_t value) { hdr.src = value; }
    void setTag(uint32_t value) { hdr.tag = value; }
    void setDataLen(uint32_t value) { hdr.dataLen = value; }
    void setMsgID(uint32_t value) { hdr.msgID = value; }
    void setMsgType(uint32_t value) { hdr.msgType = value; }
    void setEpochID(uint32_t value) { hdr.epochID = value; }
    void setTotalRank(uint32_t value) { hdr.totalRank = value; }

    // Getter and setter method for payload
    void* getPayload() const { return payload; }
    void setPayload(void* value) { payload = value; }

    void DeserializeFromArray(void* array);
    void SerializeToArray(void* array);

    void printHeader() const {
        std::cout << "Header information: ";
        std::cout << "cmdID=" << hdr.cmdID << ", ";
        std::cout << "cmdLen=" << hdr.cmdLen << ", ";
        std::cout << "dst=" << hdr.dst << ", ";
        std::cout << "src=" << hdr.src << ", ";
        std::cout << "tag=" << hdr.tag << ", ";
        std::cout << "dataLen=" << hdr.dataLen << ", ";
        std::cout << "msgID=" << hdr.msgID << ", ";
        std::cout << "msgType=" << hdr.msgType << ", ";
        std::cout << "epochID=" << hdr.epochID << ", ";
        std::cout << "totalRank=" << hdr.totalRank << std::endl;
    }

    void printPayload() const {
        unsigned char* payloadBytes = reinterpret_cast<unsigned char*>(payload);

        std::cout << "Payload in hex:" << std::endl;
        for (uint32_t i = 0; i < hdr.dataLen; i++) {
            std::cout << std::setw(2) << std::setfill('0') << std::hex << static_cast<int>(payloadBytes[i]);
            if ((i + 1) % 16 == 0) {
                std::cout << std::endl;
            } else {
                std::cout << " ";
            }
        }
        std::cout << std::endl;
    }

    uint32_t ByteSize() const {
        return (hdr.cmdLen+hdr.dataLen);
    }

};
