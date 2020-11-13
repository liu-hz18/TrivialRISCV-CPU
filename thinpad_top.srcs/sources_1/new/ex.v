`timescale 1ns / 1ps
`include "defines.v"

module ex(
    input wire rst,
    input wire[`AluOpWidth-1:0] alu_op_i,
    input wire[1:0] alu_sel_a,
    input wire[1:0] alu_sel_b,

    // A操作数来源
    input wire[`RegBus] pc,
    input wire[`RegBus] pc_now,
    input wire[`RegBus] reg_a,
    // B操作数来源
    input wire[`RegBus] imm_b,
    input wire[`RegBus] reg_b,

    output wire[`RegBus] result
);

wire[`RegBus] src_a;
wire[`RegBus] src_b;

// 源操作数多路选择器
assign src_a = (alu_sel_a == `ALU_SRCA_PC) ? pc : ((alu_sel_a == `ALU_SRCA_PCNOW) ? pc_now : reg_a);
assign src_b = (alu_sel_b == `ALU_SRCB_4) ? 4 : ((alu_sel_b == `ALU_SRCB_IMM) ? imm_b : reg_b);

alu _alu(
    .rst(rst),
    .alu_op_i(alu_op_i),
    .src_a(src_a),
    .src_b(src_b),
    .result(result)
);

endmodule
