`timescale 1ns / 1ps
`include "defines.v"
// 译码ID阶段
module ctrl(
    input wire rst,
    input wire[`InstBus] inst_i,

    // 来自寄存器的输出
    input wire[`RegBus] rs1_data_i,
    input wire[`RegBus] rs2_data_i,

    // ALU控制信号
    output reg[1:0] alu_sel_a_o,
    output reg[1:0] alu_sel_b_o,
    output reg[`AluOpWidth-1:0] alu_op_o,

    // 送到EX阶段的输出
    output reg[`RegBus] rs1_data_o,
    output reg[`RegBus] rs2_data_o,

    // 送到PC REG的branch信息
    output reg branch_flag_o,

    // 由指令生成立即数
    output reg[`RegBus] imm_o,

    // regfile控制信号
    output reg read_rs1,
    output reg read_rs2,
    output reg[`RegAddrBus] rs1_addr,
    output reg[`RegAddrBus] rs2_addr,
    output reg[`RegAddrBus] rd_addr,

    output reg write_reg,
    // 访存信息
    output reg mem_read,
    output reg mem_write
);

wire[6:0] opcode = inst_i[6:0];
wire[2:0] func3 = inst_i[14:12];
wire[31:25] func7_or_imm = inst_i[31:25];

localparam OPCODE_ADD = 7'b0110011;
localparam OPCODE_ORI = 7'b0010011;
localparam OPCODE_LW  = 7'b0000011;
localparam OPCODE_SW  = 7'b0100011;
localparam OPCODE_BEQ = 7'b1100011;

// 指令译码，组合逻辑
always @(*) begin
    if (rst) begin
        {read_rs1, read_rs2} = 2'b00;
        rs1_addr = `ZERO_REG_ADDR;
        rs2_addr = `ZERO_REG_ADDR;
        rd_addr = `ZERO_REG_ADDR;
        {alu_sel_a_o, alu_sel_b_o} = 4'b0000;
        alu_op_o = `ALU_OP_NOP;
        imm_o = `ZERO_WORD;
        branch_flag_o = 1'b0;
        write_reg = 1'b0;
        {mem_read, mem_write} <= 2'b00;
    end else begin
        {read_rs1, read_rs2} = 2'b00;
        rs1_addr = `ZERO_REG_ADDR;
        rs2_addr = `ZERO_REG_ADDR;
        rd_addr = `ZERO_REG_ADDR;
        {alu_sel_a_o, alu_sel_b_o} = 4'b0000;
        alu_op_o = `ALU_OP_NOP;
        imm_o = `ZERO_WORD;
        branch_flag_o = 1'b0;
        write_reg = 1'b0;
        {mem_read, mem_write} = 2'b00;
        case (opcode)
        OPCODE_ADD: begin
            alu_op_o = `ALU_OP_ADD;
            read_rs1 = 1'b1; // 读2个寄存器
            read_rs2 = 1'b1;
            write_reg = 1'b1;
            rs1_addr = inst_i[19:15];
            rs2_addr = inst_i[24:20];
            rd_addr = inst_i[11:7];
            alu_sel_a_o = `ALU_SRCA_REGA; // 设置ALU输入来自寄存器a, b
            alu_sel_b_o = `ALU_SRCB_REGB;
        end
        OPCODE_ORI: begin
            alu_op_o = `ALU_OP_OR;
            read_rs1 = 1'b1; // 只读rs1
            write_reg = 1'b1;
            rs1_addr = inst_i[19:15];
            rd_addr = inst_i[11:7];
            imm_o = {{20{inst_i[31]}}, inst_i[31:20]};  // 符号扩展至32位
            alu_sel_a_o = `ALU_SRCA_REGA; // 设置ALU输入来自寄存器a, b
            alu_sel_b_o = `ALU_SRCB_IMM;
        end
        OPCODE_LW: begin
            alu_op_o = `ALU_OP_ADD;
            read_rs1 = 1'b1; // 只读rs1
            write_reg = 1'b1;
            mem_read = 1'b1;
            rs1_addr = inst_i[19:15];
            rd_addr = inst_i[11:7];
            alu_sel_a_o = `ALU_SRCA_REGA; // 设置ALU输入来自寄存器a, b
            alu_sel_b_o = `ALU_SRCB_IMM;
            imm_o = {{20{inst_i[31]}}, inst_i[31:20]};  // 符号扩展至32位
        end
        OPCODE_SW: begin
            alu_op_o = `ALU_OP_ADD;
            read_rs1 = 1'b1; // 读rs1和rs2
            read_rs2 = 1'b1;
            mem_write = 1'b1;
            rs1_addr = inst_i[19:15];
            rs2_addr = inst_i[24:20];
            alu_sel_a_o = `ALU_SRCA_REGA; // 设置ALU输入来自寄存器a, b
            alu_sel_b_o = `ALU_SRCB_IMM;
            imm_o = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};  // 符号扩展至32位
        end
        OPCODE_BEQ: begin
            alu_op_o = `ALU_OP_ADD;
            read_rs1 = 1'b1; // 读2个寄存器
            read_rs2 = 1'b1;
            rs1_addr = inst_i[19:15];
            rs2_addr = inst_i[24:20];
            alu_sel_a_o = `ALU_SRCA_PC; // 设置ALU输入来自PC和IMM
            alu_sel_b_o = `ALU_SRCB_IMM;
            if (rs1_data_o == rs2_data_o) begin
                branch_flag_o = 1'b1;
                imm_o = {{19{inst_i[31]}}, inst_i[31], inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};  // 符号扩展至32位
            end else begin
                branch_flag_o = 1'b0;
            end
        end
        default: begin

        end
        endcase
    end
end

// 确定A寄存器数据
always @(*) begin
    if (rst) begin
        rs1_data_o = `ZERO_WORD;
    end else if (read_rs1 == 1'b1) begin
        rs1_data_o = rs1_data_i;
    end else begin
        rs1_data_o = `ZERO_WORD;
    end
end

// 确定B寄存器数据
always @(*) begin
    if (rst) begin
        rs2_data_o = `ZERO_WORD;
    end else if (read_rs2 == 1'b1) begin
        rs2_data_o = rs2_data_i;
    end else begin
        rs2_data_o = `ZERO_WORD;
    end
end

endmodule
