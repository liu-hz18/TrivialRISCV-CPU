`timescale 1ns / 1ps
`include "defines.v"

module reg_file(
    input wire clk,
    input wire rst,

    input wire read_rs1,  // 读寄存器有效
    input wire read_rs2,
    input wire write_reg, // 写寄存器

    input wire[`RegAddrBus] rs1_addr,
    input wire[`RegAddrBus] rs2_addr,
    input wire[`RegAddrBus] rd_addr,

    output reg[`RegBus] rs1_data,
    output reg[`RegBus] rs2_data,
    input wire[`RegBus] rd_data
);

reg[`RegBus] registers[0:31];

// 写寄存器
always @(posedge clk) begin
    if (~rst) begin
        if (write_reg && (rd_addr != `ZERO_REG_ADDR)) begin // 保证0号寄存器一直为0
            registers[rd_addr] <= rd_data;
        end
    end
end

always @(*) begin
    if (rst) begin
        rs1_data = `ZERO_WORD;
    end else if (rs1_addr == `ZERO_REG_ADDR) begin
        rs1_data = `ZERO_WORD;
    end else if ((rs1_addr == rd_addr) && write_reg && read_rs1) begin // 数据旁路
        rs1_data = rd_data;
    end else if(read_rs1 == 1'b1) begin
        rs1_data = registers[rs1_addr];
    end else begin
        rs1_data = `ZERO_WORD;
    end
end

always @(*) begin
    if (rst) begin
        rs2_data = `ZERO_WORD;
    end else if (rs2_addr == `ZERO_REG_ADDR) begin
        rs2_data = `ZERO_WORD;
    end else if ((rs2_addr == rd_addr) && write_reg && read_rs2) begin // 数据旁路
        rs2_data = rd_data;
    end else if (read_rs2 == 1'b1) begin
        rs2_data = registers[rs2_addr];
    end else begin
        rs2_data = `ZERO_WORD;
    end
end

endmodule
