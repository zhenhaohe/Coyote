
	
package bftTypes;

    typedef struct packed {
        logic [31:0] epochID;
        logic [31:0] msgType;
        logic [31:0] msgID;
        logic [31:0] dataLen; //total byte len of data (payload+digest+auth) to each primitive
        logic [31:0] tag; // tag, reserved
        logic [31:0] src; // src rank
        logic [31:0] dst; // either dst rank or communicator ID depends on primitive
        logic [31:0] cmdLen; // total byte len of compulsory & optional cmd fields
        logic [31:0] cmdID; // specifier of different communication primitive
    } bft_hdr_t;

endpackage