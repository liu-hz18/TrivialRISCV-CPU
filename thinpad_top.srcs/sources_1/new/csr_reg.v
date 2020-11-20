`timescale 1ns / 1ps
`include "defines.v"

module csr_reg(
    input wire clk,
    input wire rst,

    input wire[4:0] csr_write_en,

    output reg[`RegBus] mtvec_data_o,
    output reg[`RegBus] mscratch_data_o,
    output reg[`RegBus] mepc_data_o,
    output reg[`RegBus] mcause_data_o,
    output reg[`RegBus] mstatus_data_o,

    input wire[`RegBus] mtvec_data_i,
    input wire[`RegBus] mscratch_data_i,
    input wire[`RegBus] mepc_data_i,
    input wire[`RegBus] mcause_data_i,
    input wire[`RegBus] mstatus_data_i
);

reg[`RegBus] mtvec_reg;
reg[`RegBus] mscratch_reg;
reg[`RegBus] mepc_reg;
reg[`RegBus] mcause_reg;
reg[`RegBus] mstatus_reg;

// 写寄存器
// mtvec
always @(posedge clk) begin
    if (~rst) begin
        if (csr_write_en[4]) begin
            mtvec_reg <= mtvec_data_i;
        end
    end
end

// mepc
always @(posedge clk) begin
    if (~rst) begin
        if (csr_write_en[3]) begin
            mepc_reg <= mepc_data_i;
        end
    end
end

// mcause
always @(posedge clk) begin
    if (~rst) begin
        if (csr_write_en[2]) begin
            mcause_reg <= mcause_data_i;
        end
    end
end

// mscratch
always @(posedge clk) begin
    if (~rst) begin
        if (csr_write_en[1]) begin
            mscratch_reg <= mscratch_data_i;
        end
    end
end

// mstatus
always @(posedge clk) begin
    if (~rst) begin
        if (csr_write_en[0]) begin
            mstatus_reg <= mstatus_data_i;
        end
    end
end

// 读寄存器
// mtvec
always @(*) begin
    if (rst) begin
        mtvec_data_o = `ZERO_WORD;
    end else begin
        mtvec_data_o = mtvec_reg;
    end
end

// mscratch
always @(*) begin
    if (rst) begin
        mscratch_data_o = `ZERO_WORD;
    end else begin
        mscratch_data_o = mscratch_reg;
    end
end

// mepc
always @(*) begin
    if (rst) begin
        mepc_data_o = `ZERO_WORD;
    end else begin
        mepc_data_o = mepc_reg;
    end
end

// mcause
always @(*) begin
    if (rst) begin
        mcause_data_o = `ZERO_WORD;
    end else begin
        mcause_data_o = mcause_reg;
    end
end

// mstatus
always @(*) begin
    if (rst) begin
        mstatus_data_o = `ZERO_WORD;
    end else begin
        mstatus_data_o = mstatus_reg;
    end
end

endmodule
