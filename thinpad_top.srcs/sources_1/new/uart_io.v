`timescale 1ns / 1ps

module uart_io(
    input wire clk,
    input wire rst,
    input wire oen,
    input wire wen,

    input wire[7:0] data_in,
    output reg[7:0] data_out,
    output wire done,

    input wire[31:0] uart_data_wire_in,

    output reg uart_rdn,
    output reg uart_wrn,
    input wire uart_dataready,
    input wire uart_tbre,
    input wire uart_tsre
);

localparam STATE_IDLE          = 4'b0000;
localparam STATE_READ_0        = 4'b0001;
localparam STATE_READ_1        = 4'b0010;
localparam STATE_READ_BLANK    = 4'b0011;
localparam STATE_WRITE_0       = 4'b0100;
localparam STATE_WRITE_1       = 4'b0101;
localparam STATE_WRITE_2       = 4'b0110;
localparam STATE_WRITE_3       = 4'b0111;
localparam STATE_WRITE_BLANK_0 = 4'b1000;
localparam STATE_WRITE_BLANK_1 = 4'b1001;
localparam STATE_DONE          = 4'b1010;

reg[3:0] state; //4 bit
assign done = (state == STATE_DONE);

always @(posedge clk or posedge rst) begin
    if (rst) begin
        { uart_rdn, uart_wrn } <= 2'b11;
        state <= STATE_IDLE;
    end
    else begin
        case (state)
            STATE_IDLE: begin
                if (~oen) begin //可以从串口读数据了
                    state <= STATE_READ_0;
                end
                else if (~wen) begin //往串口写数据
                    //data_out <= data_in;
                    state <= STATE_WRITE_0;
                end
            end
            STATE_READ_0: begin // if语句配合状态机，实际上实现了忙等待
                if (uart_dataready) begin
                    uart_rdn <= 1'b0; // 打开读使能， 实际上uart_rdn下降沿之后，下一个周期uart_dataready就变0了
                    state <= STATE_READ_BLANK;
                end
            end
            STATE_READ_BLANK: begin // 读串口也要插空拍，不然可能读不到数据
                state <= STATE_READ_1;
            end
            STATE_READ_1: begin
                data_out <= uart_data_wire_in[7:0]; // 从数据总线读出数据
                uart_rdn <= 1'b1; // 关闭读使能
                state <= STATE_DONE;
            end
            STATE_WRITE_0: begin
                uart_wrn <= 1'b0; // 写使能打开
                state <= STATE_WRITE_BLANK_0;
            end
            STATE_WRITE_BLANK_0: begin // 写串口，插入2个空拍
                state <= STATE_WRITE_BLANK_1;
            end
            STATE_WRITE_BLANK_1: begin
                state <= STATE_WRITE_1;
            end
            STATE_WRITE_1: begin
                uart_wrn <= 1'b1; // 写使能关闭
                state <= STATE_WRITE_2;
            end
            STATE_WRITE_2: begin
                if (uart_tbre)  // 等待发送数据标志为1
                    state <= STATE_WRITE_3;
            end
            STATE_WRITE_3: begin
                if (uart_tsre)  // 等待发送完毕标志为1
                    state <= STATE_DONE;
            end
            STATE_DONE: begin
                if (oen&wen) begin
                    { uart_rdn, uart_wrn } <= 2'b11; // 读写使能关闭
                    state <= STATE_IDLE;  // 回到初始状态
                end
            end
        endcase
    end
end

endmodule
