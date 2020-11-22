`timescale 1ns / 1ps
`include "defines.v"

module tlb(
    input wire clk,
    input wire rst,

    input wire read_en,
    input wire write_en,

    input wire[`TLB_INDEX_WIDTH-1:0] index,        // 18:12, 7bit
    input wire[`TLB_VPN_PRE_WIDTH-1:0] vpn_prefix, // 31:19, 13bit

    // 读TLB
    output reg tlb_hit, // 是否命中
    output reg[`TLB_PPN_WIDTH-1:0] ppn_o, // 物理地址，用于拼接offset

    // 缓存，写TLB
    input wire[`TLB_PPN_WIDTH-1:0] ppn_i // 20bit
);

reg[32:0] tlb_regs[0:127]; // 13+20, 31:19 | 31:12

// 写TLB
always @(posedge clk) begin
    if (~rst) begin
        if (write_en) begin
            tlb_regs[index] <= {vpn_prefix, ppn_i}; 
        end
    end
end

// 读TLB
always @(*) begin
    if (rst) begin
        tlb_hit = 1'b0;
        ppn_o = 20'h0_0000;
    end else if (tlb_regs[index][32:20] == vpn_prefix) begin
        tlb_hit = 1'b1;
        ppn_o = tlb_regs[index][19:0];
    end else begin
        tlb_hit = 1'b0;
        ppn_o = 20'h0_0000;
    end
end

endmodule
