`timescale 1ns / 1ps

module io_control(
    input wire clk,
    input wire rst,
    input wire oen,
    input wire wen,
    input wire ram_or_uart,

    input wire[31:0] data_in,
    output reg[31:0] data_out,
    output wire done,

    inout wire[31:0] base_ram_data_wire, //数据总线

    input wire[19:0] address,

    //CPLD串口控制器信号
    output wire uart_rdn,
    output wire uart_wrn,
    input wire uart_dataready,
    input wire uart_tbre,
    input wire uart_tsre,

    //BaseRAM控制信号
    output wire[19:0] base_ram_addr,
    output wire[3:0] base_ram_be_n,
    output wire base_ram_ce_n,
    output wire base_ram_oe_n,
    output wire base_ram_we_n
);

reg oe_uart_n, we_uart_n;
reg[7:0] data_uart_in;
wire[7:0] data_uart_out;
wire uart_done;

reg oe_sram_n, we_sram_n;
reg[31:0] data_sram_in;
wire[31:0] data_sram_out;
wire sram_done;

// 总线控制逻辑，三态端口
reg data_z;
reg[31:0] data_to_reg;
assign base_ram_data_wire = (~data_z) ? data_to_reg : 32'bz;

localparam STATE_IDLE              = 4'b0000;

localparam STATE_START_UART_READ   = 4'b0001;
localparam STATE_FINISH_UART_READ  = 4'b0010;
localparam STATE_START_MEM_WRITE   = 4'b0011;
localparam STATE_FINISH_MEM_WRITE  = 4'b0100;

localparam STATE_START_MEM_READ    = 4'b0101;
localparam STATE_FINISH_MEM_READ   = 4'b0110;
localparam STATE_START_UART_WRITE  = 4'b0111;
localparam STATE_FINISH_UART_WRITE = 4'b1000;
localparam STATE_DONE              = 4'b1001;

reg[3:0] state; //4 bit
assign done = (state == STATE_DONE);

uart_io _uart_io(
    .clk(clk),
    .rst(rst),
    .oen(oe_uart_n),
    .wen(we_uart_n),
    .data_in(data_uart_in),
    .data_out(data_uart_out),
    .done(uart_done),

    .uart_data_wire_in(base_ram_data_wire),

    .uart_rdn(uart_rdn), 
    .uart_wrn(uart_wrn), 
    .uart_dataready(uart_dataready),
    .uart_tbre(uart_tbre), 
    .uart_tsre(uart_tsre)
);

sram_io _sram_io(
    .clk(clk),
    .rst(rst),
    .oen(oe_sram_n),
    .wen(we_sram_n),
    .data_in(data_sram_in),
    .data_out(data_sram_out),
    .done(sram_done),

    .base_ram_data_wire_in(base_ram_data_wire),

    .address(address),
    .base_ram_addr(base_ram_addr),
    .base_ram_be_n(), //字节使能 输出暂且不用，悬空
    .base_ram_ce_n(base_ram_ce_n),
    .base_ram_oe_n(base_ram_oe_n),
    .base_ram_we_n(base_ram_we_n)
);

assign base_ram_be_n = 4'b0000;

always @(posedge clk or posedge rst) begin
    if (rst) begin
        {oe_uart_n, we_uart_n} <= 2'b11;
        {oe_sram_n, we_sram_n} <= 2'b11;
        data_z <= 1'b1;
        state <= STATE_IDLE;
    end
    else begin
        case (state)
            STATE_IDLE: begin
                if(~oen) begin //读数据
                    if (ram_or_uart) begin// 读RAM
                        state <= STATE_START_MEM_READ;
                    end
                    else begin
                        state <= STATE_START_UART_READ;
                    end
                end
                else if (~wen) begin //写数据
                    if (ram_or_uart) begin//写RAM
                        state <= STATE_START_MEM_WRITE;
                    end
                    else begin
                        state <= STATE_START_UART_WRITE;
                    end
                end
            end
            //读串口
            STATE_START_UART_READ: begin
                if (uart_dataready) begin
                    data_z <= 1'b1;
                    oe_uart_n <= 1'b0;
                    state <= STATE_FINISH_UART_READ;
                end
            end
            STATE_FINISH_UART_READ: begin
                if (uart_done) begin // 读串口有问题
                    {oe_uart_n, we_uart_n} <= 2'b11;
                    data_out <= data_uart_out;
                    state <= STATE_DONE;
                end
            end
            // 读内存
            STATE_START_MEM_READ: begin
                data_z <= 1'b1;
                oe_sram_n <= 1'b0;
                state <= STATE_FINISH_MEM_READ;
            end
            STATE_FINISH_MEM_READ: begin
                if (sram_done) begin
                    {oe_sram_n, we_sram_n} <= 2'b11;
                    data_out <= data_sram_out;
                    state <= STATE_DONE;
                end
            end
            //写串口
            STATE_START_UART_WRITE: begin
                data_z <= 1'b0;        // 作为发送方，base_ram_data置为要输入的数据
                we_uart_n <= 1'b0;
                data_to_reg <= data_in;
                state <= STATE_FINISH_UART_WRITE;
            end
            STATE_FINISH_UART_WRITE: begin
                if (uart_done) begin
                    data_z <= 1'b1;
                    {oe_uart_n, we_uart_n} <= 2'b11;
                    state <= STATE_DONE;
                end
            end
            //写内存
            STATE_START_MEM_WRITE: begin
                data_z <= 1'b0;        // 作为发送方，base_ram_data置为要输入的数据
                we_sram_n <= 1'b0; //打开写内存
                data_to_reg <= data_in;
                state <= STATE_FINISH_MEM_WRITE;
            end
            STATE_FINISH_MEM_WRITE: begin
                if (sram_done) begin
                    data_z <= 1'b1;
                    {oe_sram_n, we_sram_n} <= 2'b11;
                    state <= STATE_DONE;
                end
            end
            STATE_DONE: begin
                if(oen & wen) begin
                    {oe_uart_n, we_uart_n} <= 2'b11;
                    {oe_sram_n, we_sram_n} <= 2'b11;
                    data_z <= 1'b1;
                    state <= STATE_IDLE;
                end
            end
        endcase
    end
end

endmodule
