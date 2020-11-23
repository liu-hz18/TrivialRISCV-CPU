`timescale 1ns / 1ps
`include "defines.v"

module io_control(
    input wire clk,
    input wire rst,
    input wire oen,
    input wire wen,

    input wire byte_en, // lb, lw指令

    input wire[`RegBus] data_in,
    output reg[`RegBus] data_out,
    output wire done,

    inout wire[`RegBus] base_ram_data_wire, // BaseRAM & UART数据总线
    inout wire[`RegBus] ext_ram_data_wire,  // ExtRAM 数据总线

    input wire[`RegBus] address,

    //CPLD串口控制器信号
    output wire uart_rdn,
    output wire uart_wrn,
    input wire uart_dataready,
    input wire uart_tbre,
    input wire uart_tsre,

    //BaseRAM控制信号
    output wire[`RAMAddrBus] base_ram_addr,
    output wire[3:0] base_ram_be_n,
    output wire      base_ram_ce_n,
    output wire      base_ram_oe_n,
    output wire      base_ram_we_n,

    // ExtRAM控制信号
    output wire[`RAMAddrBus] ext_ram_addr,
    output wire[3:0] ext_ram_be_n,
    output wire      ext_ram_ce_n,
    output wire      ext_ram_oe_n,
    output wire      ext_ram_we_n
);

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

// 地址仲裁
wire ram_or_uart = (address >= 32'h8000_0000);
wire use_ext_ram_bus = address[22];  // 为 1 时选择ext_ram

// RAM控制信号
reg oe_sram_n, we_sram_n;

// ExtRAM控制信号
wire ext_oe_sram_n = (use_ext_ram_bus && ram_or_uart) ? oe_sram_n : 1'b1;
wire ext_we_sram_n = (use_ext_ram_bus && ram_or_uart) ? we_sram_n : 1'b1;
wire[`RegBus] data_ext_ram_out; // 从内存读到串口
wire ext_ram_done;

// BaseRAM控制信号
wire base_oe_sram_n = (~use_ext_ram_bus && ram_or_uart) ? oe_sram_n : 1'b1;
wire base_we_sram_n = (~use_ext_ram_bus && ram_or_uart) ? we_sram_n : 1'b1;
wire[`RegBus] data_base_ram_out; // 从内存读到串口
wire base_ram_done;

// 两个RAM结合起来
wire sram_done = ext_ram_done | base_ram_done; // 内存读写完成
wire[`RegBus] data_sram_out = use_ext_ram_bus ? data_ext_ram_out : data_base_ram_out;

// 串口控制信号
reg oe_uart_n, we_uart_n;
wire[7:0] data_uart_out;
wire uart_done;

// 总线控制逻辑，三态端口
reg data_z;
reg[`RegBus] data_to_reg;
assign base_ram_data_wire = (~data_z && ((~use_ext_ram_bus && ram_or_uart) || ~ram_or_uart)) ? data_to_reg : 32'bz;
assign ext_ram_data_wire  = (~data_z &&  use_ext_ram_bus && ram_or_uart) ? data_to_reg : 32'bz;

uart_io _uart_io(
    .clk(clk),
    .rst(rst),
    .oen(oe_uart_n),
    .wen(we_uart_n),

    .data_out(data_uart_out),
    .done(uart_done),

    .uart_data_wire_in(base_ram_data_wire),

    .uart_rdn(uart_rdn),
    .uart_wrn(uart_wrn),
    .uart_dataready(uart_dataready),
    .uart_tbre(uart_tbre),
    .uart_tsre(uart_tsre)
);

// BaseRAN模块
sram_io _base_ram_io(
    .clk(clk),
    .rst(rst),
    .oen(base_oe_sram_n),
    .wen(base_we_sram_n),
    .byte_en(byte_en),

    .data_out(data_base_ram_out),
    .done(base_ram_done),

    .ram_data_wire_in(base_ram_data_wire),

    .address(address),
    .ram_addr(base_ram_addr),
    .ram_be_n(base_ram_be_n), //字节使能
    .ram_ce_n(base_ram_ce_n),
    .ram_oe_n(base_ram_oe_n),
    .ram_we_n(base_ram_we_n)
);


// ExtRAM模块
sram_io _ext_ram_io(
    .clk(clk),
    .rst(rst),
    .oen(ext_oe_sram_n),
    .wen(ext_we_sram_n),
    .byte_en(byte_en),

    .data_out(data_ext_ram_out),
    .done(ext_ram_done),

    .ram_data_wire_in(ext_ram_data_wire),

    .address(address),
    .ram_addr(ext_ram_addr),
    .ram_be_n(ext_ram_be_n), //字节使能
    .ram_ce_n(ext_ram_ce_n),
    .ram_oe_n(ext_ram_oe_n),
    .ram_we_n(ext_ram_we_n)
);


always @(posedge clk or posedge rst) begin
    if (rst) begin
        {oe_uart_n, we_uart_n} <= 2'b11;
        {oe_sram_n, we_sram_n} <= 2'b11;
        data_z <= 1'b1;
        data_to_reg <= `ZERO_WORD;
        data_out <= `ZERO_WORD;
        state <= STATE_IDLE;
    end
    else begin
        case (state)
            STATE_IDLE: begin
                if(~oen) begin //读数据
                    if (ram_or_uart) begin // 读RAM
                        //state <= STATE_START_MEM_READ;
                        data_z <= 1'b1;
                        oe_sram_n <= 1'b0;
                        state <= STATE_FINISH_MEM_READ;
                    end else if (address == 32'h1000_0000) begin
                        //state <= STATE_START_UART_READ;
                        data_z <= 1'b1;
                        oe_uart_n <= 1'b0;
                        state <= STATE_FINISH_UART_READ;
                    end else if (address == 32'h1000_0005) begin // 读串口状态位
                        //data_out <= {24'h00_0000, 2'b00, 1'b1, 4'b0000, 1'b1};
                        data_out <= {24'h00_0000, 2'b00, uart_tbre&uart_tsre, 4'b0000, uart_dataready};
                        state <= STATE_DONE;
                    end else begin
                        // 非法地址
                        state <= STATE_DONE;
                    end
                end
                else if (~wen) begin //写数据
                    if (ram_or_uart) begin//写RAM
                        //state <= STATE_START_MEM_WRITE;
                        data_z <= 1'b0;        // 作为发送方，base_ram_data置为要输入的数据
                        we_sram_n <= 1'b0; //打开写内存
                        if (byte_en) begin
                            data_to_reg <= {24'h00_0000, data_in[7:0]} << ((address & 32'h0000_0003) << 3);
                        end else begin
                            data_to_reg <= data_in;
                        end
                        state <= STATE_FINISH_MEM_WRITE;
                    end else if (address == 32'h1000_0000) begin
                        //state <= STATE_START_UART_WRITE;
                        data_z <= 1'b0;        // 作为发送方，base_ram_data置为要输入的数据
                        we_uart_n <= 1'b0;
                        data_to_reg <= data_in;
                        state <= STATE_FINISH_UART_WRITE;
                    end else begin
                        // 非法地址 或 不允许写串口状态位
                        state <= STATE_DONE;
                    end
                end
            end
            //读串口
            STATE_START_UART_READ: begin
                data_z <= 1'b1;
                oe_uart_n <= 1'b0;
                state <= STATE_FINISH_UART_READ;
            end
            STATE_FINISH_UART_READ: begin
                if (uart_done) begin
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
                if (byte_en) begin
                    data_to_reg <= {24'h00_0000, data_in[7:0]} << ((address & 32'h0000_0003) << 3);
                end else begin
                    data_to_reg <= data_in;
                end
                state <= STATE_FINISH_MEM_WRITE;
            end
            STATE_FINISH_MEM_WRITE: begin
                if (sram_done) begin
                    data_z <= 1'b1;
                    {oe_sram_n, we_sram_n} <= 2'b11;
                    state <= STATE_DONE;
                end
            end
            // 结束状态
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
