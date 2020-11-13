`timescale 1ns / 1ps
`include "defines.v"
// 多周期CPU总控状态机
module cpu(
    input wire clk,
    input wire rst,

    input wire done,
    input wire branch_flag_i,
    input wire link_flag_i,
    input wire write_reg,

    input wire[`RegBus] ex_result_i,
    input wire[`RegBus] ram_data_i,
    input wire mem_read,
    input wire mem_write,
    input wire mem_byte_en,

    input wire[`RegBus] rs1_data_i,
    input wire[`RegBus] rs2_data_i,

    output reg io_oen,
    output reg io_wen,
    output reg io_byte_en,
    output reg[`RegBus] ram_data_o,
    
    output wire[`RegBus] address,
    output wire write_reg_buf,

    output reg[`InstBus] inst,
    output reg[`RegBus] pc,
    output reg[`RegBus] pc_now,
    output reg[`RegBus] rd_data_o
);

localparam STAGE_IF_BEGIN = 3'b000;
localparam STAGE_IF_FINISH = 3'b001;
localparam STAGE_ID = 3'b010;
localparam STAGE_EX = 3'b011;
localparam STAGE_MEM_BEGIN = 3'b100;
localparam STAGE_MEM_FINISH = 3'b101;
localparam STAGE_WB = 3'b110;

reg[2:0] state;

assign address = (state == STAGE_IF_BEGIN || state == STAGE_IF_FINISH) ? pc : ex_result_i; // SRAM地址
assign write_reg_buf = (state == STAGE_WB) ? write_reg : 1'b0;

always @(posedge clk) begin
    if (rst) begin
        {io_oen, io_wen, io_byte_en} <= 3'b110;
        pc <= `PC_INIT_ADDR;
        pc_now <= `PC_INIT_ADDR;
        inst <= `ZERO_WORD;
        rd_data_o <= `ZERO_WORD;
        ram_data_o <= `ZERO_WORD;
        state <= STAGE_IF_BEGIN;
    end else begin
        case (state)
        STAGE_IF_BEGIN: begin
            io_oen <= 1'b0; // 读内存模式
            pc_now <= pc;
            state <= STAGE_IF_FINISH;
        end
        STAGE_IF_FINISH: begin
            if (done) begin // busy-waiting for instruction
                {io_oen, io_wen, io_byte_en} <= 3'b110;
                inst <= ram_data_i; // 取出指令
                state <= STAGE_ID;            
            end
        end
        STAGE_ID: begin // 控制信息都在一个周期内给出
            state <= STAGE_EX;
        end
        STAGE_EX: begin  // 运算结果在一个周期内给出
            state <= STAGE_MEM_BEGIN;
        end
        STAGE_MEM_BEGIN: begin
            if (mem_read == 1'b1) begin
                io_oen <= 1'b0;
                if (mem_byte_en) begin
                    io_byte_en <= 1'b1;
                end
                state <= STAGE_MEM_FINISH;
            end else if (mem_write == 1'b1) begin
                io_wen <= 1'b0;
                ram_data_o <= rs2_data_i;
                if (mem_byte_en) begin
                    io_byte_en <= 1'b1;
                end
                state <= STAGE_MEM_FINISH;
            end else begin
                if (link_flag_i) begin
                    rd_data_o <= pc + 4;
                end else begin
                    rd_data_o <= ex_result_i;
                end
                state <= STAGE_WB;
            end
        end
        STAGE_MEM_FINISH: begin
            if (done) begin
                {io_oen, io_wen, io_byte_en} <= 3'b110;
                state <= STAGE_WB;
                if (mem_read) begin
                    rd_data_o <= ram_data_i; // 取出读到的值
                end
            end
        end
        STAGE_WB: begin
            if (branch_flag_i) begin // 更新PC
                pc <= ex_result_i;
            end else begin
                pc <= pc + 4;
            end
            state <= STAGE_IF_BEGIN;
        end
        endcase
    end
end

endmodule
