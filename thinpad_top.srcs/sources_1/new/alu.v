`timescale 1ns / 1ps
`include "defines.v"

// ALU模块，组合逻辑
module alu(
    input wire rst,
    input wire[`AluOpWidth-1:0] alu_op_i,

    // 操作数
    input wire[`RegBus] src_a,
    input wire[`RegBus] src_b,

    output reg[`RegBus] result
);

reg cf;
reg zf;
reg sf;
reg vf;

always @(*) begin
    if (rst) begin
        result = `ZERO_WORD;
        {cf, zf, sf, vf} = 4'b0000;
    end else begin
        result = `ZERO_WORD;
        {cf, zf, sf, vf} = 4'b0000;
        case (alu_op_i) 
        `ALU_OP_ADD: begin
            {cf, result} = src_a + src_b;
            vf = src_a[`WordWidth-1] ^ src_b[`WordWidth-1] ^ result[`WordWidth-1] ^ cf;
        end
        `ALU_OP_SUB: begin
            {cf, result} = src_a - src_b;
            vf = src_a[`WordWidth-1] ^ src_b[`WordWidth-1] ^ result[`WordWidth-1] ^ cf;
        end
        `ALU_OP_AND: begin
            result = src_a & src_b;
        end
        `ALU_OP_OR: begin
            result = src_a | src_b;
        end
        `ALU_OP_XOR: begin
            result = src_a ^ src_b;
        end
        `ALU_OP_SLL: begin
            result = src_a << src_b;
        end
        `ALU_OP_SRL: begin
            result = src_a >> src_b;
        end
        default: begin
            // do nothing
        end
        endcase
        sf = result[`WordWidth-1];
        zf = (result == `ZERO_WORD) ? 1'b1 : 1'b0;
    end
end

endmodule
