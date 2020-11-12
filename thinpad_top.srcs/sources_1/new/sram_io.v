`timescale 1ns / 1ps
`include "defines.v"

module sram_io(
    input wire clk,  //时钟输入
    input wire rst,
    input wire oen,
    input wire wen,
    input wire byte_en,

    output reg[`RegBus] data_out,
    output wire done,

    input wire[`RegBus] ram_data_wire_in,

    input wire[`RegBus] address, //读入的地址信号
    output reg[`RAMAddrBus] ram_addr, //RAM地址
    output reg[3:0] ram_be_n,       //RAM字节使能，低有效。如果不使用字节使能，请保持为0
    output reg      ram_ce_n,       //RAM片选，低有效
    output reg      ram_oe_n,       //RAM读使能，低有效
    output reg      ram_we_n        //RAM写使能，低有效
);

localparam STATE_IDLE         = 3'b000;
localparam STATE_START_READ   = 3'b001;
localparam STATE_FINISH_READ  = 3'b010;
localparam STATE_START_WRITE  = 3'b011;
localparam STATE_FINISH_WRITE = 3'b100;
localparam STATE_DONE         = 3'b101;

reg[2:0] state; //3bit
assign done = (state == STATE_DONE);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        ram_ce_n <= 1'b1;
        ram_oe_n <= 1'b1;
        ram_we_n <= 1'b1;
        ram_be_n <= 4'b0000;
        ram_addr <= `ZERO_RAM_ADDR;
        data_out <= `ZERO_WORD;
        state <= STATE_IDLE;
    end
    else begin
        case (state)
            STATE_IDLE: begin
                if(~oen) begin
                    ram_addr <= address[21:2];
                    state <= STATE_START_READ;
                end
                else if (~wen) begin
                    ram_addr <= address[21:2];
                    state <= STATE_START_WRITE;
                end else begin
                    ram_addr <= `ZERO_RAM_ADDR;
                end
            end
            STATE_START_READ: begin
                ram_ce_n <= 1'b0;
                ram_oe_n <= 1'b0;
                if (byte_en) begin
                    ram_be_n <= ~(4'b0001 << (address & 32'h00000003));
                end else begin
                    ram_be_n <= 4'b0000;
                end
                state <= STATE_FINISH_READ;
            end
            STATE_FINISH_READ: begin
                ram_ce_n <= 1'b1;
                ram_oe_n <= 1'b1;
                ram_be_n <= 4'b0000;
                if (ram_be_n == 4'b1110) begin
                    data_out <= { {24{ram_data_wire_in[7]}}, ram_data_wire_in[7:0]};
                end else if (ram_be_n == 4'b1101) begin
                    data_out <= { {24{ram_data_wire_in[15]}}, ram_data_wire_in[15:8]};
                end else if (ram_be_n == 4'b1011) begin
                    data_out <= { {24{ram_data_wire_in[23]}}, ram_data_wire_in[23:16]};
                end else if (ram_be_n == 4'b0111) begin
                    data_out <= { {24{ram_data_wire_in[31]}}, ram_data_wire_in[31:24]};
                end else begin
                    data_out <= ram_data_wire_in; // 读数据直接到data_out
                end
                state <= STATE_DONE;
            end
            STATE_START_WRITE:begin
                ram_ce_n <= 1'b0;
                ram_we_n <= 1'b0;
                if (byte_en) begin
                    ram_be_n <= ~(4'b0001 << (address & 32'h00000003));;
                end else begin
                    ram_be_n <= 4'b0000;
                end
                state <= STATE_FINISH_WRITE;
            end
            STATE_FINISH_WRITE: begin
                ram_ce_n <= 1'b1;
                ram_we_n <= 1'b1;
                ram_be_n <= 4'b0000;
                state <= STATE_DONE;
            end
            STATE_DONE:begin
                if (oen&wen) begin
                    ram_ce_n <= 1'b1;
                    ram_oe_n <= 1'b1;
                    ram_we_n <= 1'b1;
                    state <= STATE_IDLE;
                end
            end
        endcase
    end
end

endmodule
