`timescale 1ns / 1ps

`define ZERO_WORD 32'h0000_0000
`define WordWidth 32

// ALU 控制信号
`define ALU_SRCA_PC 2'b00
`define ALU_SRCA_PCNOW 2'b01
`define ALU_SRCA_REGA 2'b10

`define ALU_SRCB_4 2'b00
`define ALU_SRCB_IMM 2'b01
`define ALU_SRCB_REGB 2'b10

// ALU 操作码
`define AluOpWidth 5
`define ALU_OP_NOP 5'b00000
`define ALU_OP_ADD 5'b00001
`define ALU_OP_SUB 5'b00010
`define ALU_OP_AND 5'b00011
`define ALU_OP_OR  5'b00100

// 存储器
`define RAMAddrBus 19:0 // 地址总线宽度
`define InstBus 31:0     // 指令数据总线宽度

// 寄存器文件相关
`define ZERO_REG_ADDR 5'b00000 // 0号寄存器地址
`define RegAddrBus 4:0   // 寄存器文件地址宽度
`define RegBus 31:0      // 寄存器文件数据宽度

// 指令操作码相关

