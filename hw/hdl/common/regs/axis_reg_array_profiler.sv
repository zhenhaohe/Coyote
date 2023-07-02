`timescale 1ns / 1ps

import lynxTypes::*;

`include "axi_macros.svh"

module axis_reg_array_profiler #(
    parameter integer                       N_STAGES = 2,
    parameter integer                       DATA_BITS = AXI_DATA_BITS
) (
    input  logic                            aclk,
    input  logic                            aresetn,
    input  logic                            reset, 

    output logic [63:0]                     byte_cnt,
    output logic [63:0]                     pkt_cnt,
    output logic [63:0]                     ready_down,   

    AXI4S.s                                s_axis,
    AXI4S.m                                m_axis
);

// ----------------------------------------------------------------------------------------------------------------------- 
// -- Register slices ---------------------------------------------------------------------------------------------------- 
// ----------------------------------------------------------------------------------------------------------------------- 
AXI4S #(.AXI4S_DATA_BITS(DATA_BITS)) axis_s [N_STAGES+1] ();

`AXIS_ASSIGN(s_axis, axis_s[0])
`AXIS_ASSIGN(axis_s[N_STAGES], m_axis)

for(genvar i = 0; i < N_STAGES; i++) begin
    axis_reg #(.DATA_BITS(DATA_BITS)) inst_reg (.aclk(aclk), .aresetn(aresetn), .s_axis(axis_s[i]), .m_axis(axis_s[i+1]));  
end

// profiler counters
logic [63:0] byte_cnt_reg, pkt_cnt_reg, ready_down_reg;

always @ (posedge aclk) begin
    byte_cnt <= byte_cnt_reg;
    pkt_cnt <= pkt_cnt_reg;
    ready_down <= ready_down_reg;
end

always @(posedge aclk) begin
    if (~aresetn) begin
        byte_cnt_reg <= '0;
		pkt_cnt_reg <= '0;
        ready_down_reg <= '0;
    end
    else begin
        if (reset) begin
			byte_cnt_reg <= '0;
			pkt_cnt_reg <= '0;
            ready_down_reg <= '0;
        end

        if (axis_s[1].tvalid && ~axis_s[1].tready) begin
            ready_down_reg <= ready_down_reg + 1;
        end

        if (axis_s[1].tvalid && axis_s[1].tready) begin
			if (axis_s[1].tlast) begin
				pkt_cnt_reg <= pkt_cnt_reg + 1;
			end
            case (axis_s[1].tkeep)
                64'h1: byte_cnt_reg <= byte_cnt_reg + 1;
                64'h3: byte_cnt_reg <= byte_cnt_reg + 2;
                64'h7: byte_cnt_reg <= byte_cnt_reg + 4;
                64'hF: byte_cnt_reg <= byte_cnt_reg + 4;
                64'h1F: byte_cnt_reg <= byte_cnt_reg + 5;
                64'h3F: byte_cnt_reg <= byte_cnt_reg + 6;
                64'h7F: byte_cnt_reg <= byte_cnt_reg + 7;
                64'hFF: byte_cnt_reg <= byte_cnt_reg + 8;
                64'h1FF: byte_cnt_reg <= byte_cnt_reg + 9;
                64'h3FF: byte_cnt_reg <= byte_cnt_reg + 10;
                64'h7FF: byte_cnt_reg <= byte_cnt_reg + 11;
                64'hFFF: byte_cnt_reg <= byte_cnt_reg + 12;
                64'h1FFF: byte_cnt_reg <= byte_cnt_reg + 13;
                64'h3FFF: byte_cnt_reg <= byte_cnt_reg + 14;
                64'h7FFF: byte_cnt_reg <= byte_cnt_reg + 15;
                64'hFFFF: byte_cnt_reg <= byte_cnt_reg + 16;
                64'h1FFFF: byte_cnt_reg <= byte_cnt_reg + 17;
                64'h3FFFF: byte_cnt_reg <= byte_cnt_reg + 18;
                64'h7FFFF: byte_cnt_reg <= byte_cnt_reg + 19;
                64'hFFFFF: byte_cnt_reg <= byte_cnt_reg + 20;
                64'h1FFFFF: byte_cnt_reg <= byte_cnt_reg + 21;
                64'h3FFFFF: byte_cnt_reg <= byte_cnt_reg + 22;
                64'h7FFFFF: byte_cnt_reg <= byte_cnt_reg + 23;
                64'hFFFFFF: byte_cnt_reg <= byte_cnt_reg + 24;
                64'h1FFFFFF: byte_cnt_reg <= byte_cnt_reg + 25;
                64'h3FFFFFF: byte_cnt_reg <= byte_cnt_reg + 26;
                64'h7FFFFFF: byte_cnt_reg <= byte_cnt_reg + 27;
                64'hFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 28;
                64'h1FFFFFFF: byte_cnt_reg <= byte_cnt_reg + 29;
                64'h3FFFFFFF: byte_cnt_reg <= byte_cnt_reg + 30;
                64'h7FFFFFFF: byte_cnt_reg <= byte_cnt_reg + 31;
                64'hFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 32;
                64'h1FFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 33;
                64'h3FFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 34;
                64'h7FFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 35;
                64'hFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 36;
                64'h1FFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 37;
                64'h3FFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 38;
                64'h7FFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 39;
                64'hFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 40;
                64'h1FFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 41;
                64'h3FFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 42;
                64'h7FFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 43;
                64'hFFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 44;
                64'h1FFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 45;
                64'h3FFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 46;
                64'h7FFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 47;
                64'hFFFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 48;
                64'h1FFFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 49;
                64'h3FFFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 50;
                64'h7FFFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 51;
                64'hFFFFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 52;
                64'h1FFFFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 53;
                64'h3FFFFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 54;
                64'h7FFFFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 55;
                64'hFFFFFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 56;
                64'h1FFFFFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 57;
                64'h3FFFFFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 58;
                64'h7FFFFFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 59;
                64'hFFFFFFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 60;
                64'h1FFFFFFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 61;
                64'h3FFFFFFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 62;
                64'h7FFFFFFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 63;
                64'hFFFFFFFFFFFFFFFF: byte_cnt_reg <= byte_cnt_reg + 64;
            endcase
        end
    end
end

endmodule