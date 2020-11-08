`timescale 1ns / 1ps

module sram_io(
    input wire clk,  //时钟输入
    input wire rst,
    input wire oen,
    input wire wen,

    input wire[31:0] data_in,
    output reg[31:0] data_out,
    output wire done,

    input wire[31:0] base_ram_data_wire_in,

    input wire[19:0] address, //读入的地址信号
    output reg[19:0] base_ram_addr, //BaseRAM地址
    output reg[3:0] base_ram_be_n,  //BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output reg base_ram_ce_n,       //BaseRAM片选，低有效
    output reg base_ram_oe_n,       //BaseRAM读使能，低有效
    output reg base_ram_we_n        //BaseRAM写使能，低有效
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
        base_ram_ce_n <= 1'b1;
        base_ram_oe_n <= 1'b1;
        base_ram_we_n <= 1'b1;
        state <= STATE_IDLE;
    end
    else begin
        case (state)
            STATE_IDLE: begin
                if(~oen) begin
                    base_ram_addr <= address;
                    state <= STATE_START_READ;
                end
                else if (~wen) begin
                    base_ram_addr <= address;
                    //data_out <= data_in;
                    state <= STATE_START_WRITE;
                end
            end
            STATE_START_READ: begin
                base_ram_ce_n <= 1'b0;
                base_ram_oe_n <= 1'b0;
                state <= STATE_FINISH_READ;
            end
            STATE_FINISH_READ: begin
                base_ram_ce_n <= 1'b1;
                base_ram_oe_n <= 1'b1;
                data_out <= base_ram_data_wire_in; // 读数据直接到data_out
                state <= STATE_DONE;
            end
            STATE_START_WRITE:begin
                base_ram_ce_n <= 1'b0;
                base_ram_we_n <= 1'b0;
                state <= STATE_FINISH_WRITE;
            end
            STATE_FINISH_WRITE: begin
                base_ram_ce_n <= 1'b1;
                base_ram_we_n <= 1'b1;
                state <= STATE_DONE;
            end
            STATE_DONE:begin
                if (oen&wen) begin
                    base_ram_ce_n <= 1'b1;
                    base_ram_oe_n <= 1'b1;
                    base_ram_we_n <= 1'b1;
                    state <= STATE_IDLE;
                end
            end
        endcase
    end
end

endmodule
