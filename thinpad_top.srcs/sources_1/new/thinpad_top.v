`default_nettype none //取消默认行为
`include "defines.v"

module thinpad_top(
    input wire clk_50M,           //50MHz 时钟输入
    input wire clk_11M0592,       //11.0592MHz 时钟输入（备用，可不用）

    input wire clock_btn,         //BTN5手动时钟按钮开关，带消抖电路，按下时为1
    input wire reset_btn,         //BTN6手动复位按钮开关，带消抖电路，按下时为1

    input  wire[3:0]  touch_btn,  //BTN1~BTN4，按钮开关，按下时为1
    input  wire[31:0] dip_sw,     //32位拨码开关，拨到"ON"时为1
    output wire[15:0] leds,       //16位LED，输出时1点亮
    output wire[7:0]  dpy0,       //数码管低位信号，包括小数点，输出1点亮
    output wire[7:0]  dpy1,       //数码管高位信号，包括小数点，输出1点亮

    //CPLD串口控制器信号
    output wire uart_rdn,         //读串口信号，低有效
    output wire uart_wrn,         //写串口信号，低有效
    input wire uart_dataready,    //串口数据准备好
    input wire uart_tbre,         //发送数据标志
    input wire uart_tsre,         //数据发送完毕标志

    //BaseRAM信号
    inout wire[31:0] base_ram_data,  //BaseRAM数据，低8位与CPLD串口控制器共享
    output wire[19:0] base_ram_addr, //BaseRAM地址
    output wire[3:0] base_ram_be_n,  //BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire base_ram_ce_n,       //BaseRAM片选，低有效
    output wire base_ram_oe_n,       //BaseRAM读使能，低有效
    output wire base_ram_we_n,       //BaseRAM写使能，低有效

    //ExtRAM信号
    inout wire[31:0] ext_ram_data,  //ExtRAM数据
    output wire[19:0] ext_ram_addr, //ExtRAM地址
    output wire[3:0] ext_ram_be_n,  //ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
    output wire ext_ram_ce_n,       //ExtRAM片选，低有效
    output wire ext_ram_oe_n,       //ExtRAM读使能，低有效
    output wire ext_ram_we_n,       //ExtRAM写使能，低有效

    //直连串口信号
    output wire txd,  //直连串口发送端
    input  wire rxd,  //直连串口接收端

    //Flash存储器信号，参考 JS28F640 芯片手册
    output wire [22:0]flash_a,      //Flash地址，a0仅在8bit模式有效，16bit模式无意义
    inout  wire [15:0]flash_d,      //Flash数据
    output wire flash_rp_n,         //Flash复位信号，低有效
    output wire flash_vpen,         //Flash写保护信号，低电平时不能擦除、烧写
    output wire flash_ce_n,         //Flash片选信号，低有效
    output wire flash_oe_n,         //Flash读使能信号，低有效
    output wire flash_we_n,         //Flash写使能信号，低有效
    output wire flash_byte_n,       //Flash 8bit模式选择，低有效。在使用flash的16位模式时请设为1

    //USB 控制器信号，参考 SL811 芯片手册
    output wire sl811_a0,
    //inout  wire[7:0] sl811_d,     //USB数据线与网络控制器的dm9k_sd[7:0]共享
    output wire sl811_wr_n,
    output wire sl811_rd_n,
    output wire sl811_cs_n,
    output wire sl811_rst_n,
    output wire sl811_dack_n,
    input  wire sl811_intrq,
    input  wire sl811_drq_n,

    //网络控制器信号，参考 DM9000A 芯片手册
    output wire dm9k_cmd,
    inout  wire[15:0] dm9k_sd,
    output wire dm9k_iow_n,
    output wire dm9k_ior_n,
    output wire dm9k_cs_n,
    output wire dm9k_pwrst_n,
    input  wire dm9k_int,

    //图像输出信号
    output wire[2:0] video_red,    //红色像素，3位
    output wire[2:0] video_green,  //绿色像素，3位
    output wire[1:0] video_blue,   //蓝色像素，2位
    output wire video_hsync,       //行同步（水平同步）信号
    output wire video_vsync,       //场同步（垂直同步）信号
    output wire video_clk,         //像素时钟输出
    output wire video_de           //行数据有效信号，用于区分消隐区
);

// PLL分频示例
wire locked, clk_10M, clk_20M;
pll_example clock_gen(
  // Clock in ports
  .clk_in1(clk_50M),  // 外部时钟输入
  // Clock out ports
  .clk_out1(clk_10M), // 时钟输出1，频率在IP配置界面中设置
  .clk_out2(clk_20M), // 时钟输出2，频率在IP配置界面中设置
  // Status and control signals
  .reset(reset_btn), // PLL复位输入
  .locked(locked)    // PLL锁定指示输出，"1"表示时钟稳定，
                     // 后级电路复位信号应当由它生成（见下）
);

reg reset_of_clk10M;
// 异步复位，同步释放，将locked信号转为后级电路的复位reset_of_clk10M
always@(posedge clk_10M or negedge locked) begin
    if(~locked) reset_of_clk10M <= 1'b1;
    else        reset_of_clk10M <= 1'b0;
end

// 选择时钟和复位信号
// wire clk = clk_10M;
// wire rst = reset_of_clk10M;
wire clk = clk_50M; // 50M也是可以的
wire rst = reset_btn;

// CPU内的PC模块（PC没有独立出来）
wire[`RegBus] pc;
wire[`RegBus] pc_now;

// 连接CPU和ID模块
wire[`InstBus] inst;
wire branch_flag;
wire link_flag;
wire write_reg;
wire mem_read;
wire mem_write;
wire mem_byte_en;
wire exception_handle_flag;
wire exception_recover_flag;
wire[4:0] csr_write_en;
wire[`RegBus] mepc_data_o_id;
wire[`RegBus] mstatus_data_o_id;
wire[`RegBus] mcause_data_o_id;
wire[1:0] mode_cpu;

// 连接CPU和EX模块
wire[`RegBus] ex_result;

// 连接CPU和regfile
wire write_reg_buf;
wire[`RegBus] rd_data_i;

// 连接CPU和IO访存模块
wire io_oen, io_wen, io_byte_en;
wire[`RegBus] ram_data_o;
wire[`RegBus] ram_data_i;
wire[`RegBus] address;
wire done;

// 连接ID模块和regfile
wire read_rs1;
wire read_rs2;
wire[`RegBus] rs1_data_i;
wire[`RegBus] rs2_data_i;
wire[`RegAddrBus] rs1_addr_i;
wire[`RegAddrBus] rs2_addr_i;
wire[`RegAddrBus] rd_addr_i;

// 连接ID和EX
wire[1:0] alu_sel_a_o;
wire[1:0] alu_sel_b_o;
wire[`AluOpWidth-1:0] alu_op_o;
wire[`RegBus] rs1_data_o;
wire[`RegBus] rs2_data_o;
wire[`RegBus] imm_o;

// 连接异常寄存器和ID模块
wire[`RegBus] mtvec_data_i;
wire[`RegBus] mscratch_data_i;
wire[`RegBus] mepc_data_i;
wire[`RegBus] mcause_data_i;
wire[`RegBus] mstatus_data_i;

wire[`RegBus] mtvec_data_o;
wire[`RegBus] mscratch_data_o;
wire[`RegBus] mepc_data_o;
wire[`RegBus] mcause_data_o;
wire[`RegBus] mstatus_data_o;

wire[4:0] csr_write_en_cpu;

io_control _io_control(
    .clk(clk),
    .rst(rst),
    .oen(io_oen),
    .wen(io_wen),
    .byte_en(io_byte_en),

    .data_in(ram_data_o),
    .data_out(ram_data_i),
    .done(done),

    .base_ram_data_wire(base_ram_data),
    .ext_ram_data_wire(ext_ram_data),
    .address(address),

    .uart_rdn(uart_rdn), 
    .uart_wrn(uart_wrn), 
    .uart_dataready(uart_dataready),
    .uart_tbre(uart_tbre), 
    .uart_tsre(uart_tsre),

    .base_ram_addr(base_ram_addr),
    .base_ram_be_n(base_ram_be_n),
    .base_ram_ce_n(base_ram_ce_n),
    .base_ram_oe_n(base_ram_oe_n),
    .base_ram_we_n(base_ram_we_n),

    .ext_ram_addr(ext_ram_addr),
    .ext_ram_be_n(ext_ram_be_n),
    .ext_ram_ce_n(ext_ram_ce_n),
    .ext_ram_oe_n(ext_ram_oe_n),
    .ext_ram_we_n(ext_ram_we_n)
);

ctrl _id(  // 组合逻辑
    .rst(rst),
    .inst_i(inst),

    .rs1_data_i(rs1_data_i),
    .rs2_data_i(rs2_data_i),

    .alu_sel_a_o(alu_sel_a_o),
    .alu_sel_b_o(alu_sel_b_o),
    .alu_op_o(alu_op_o),

    .rs1_data_o(rs1_data_o),
    .rs2_data_o(rs2_data_o),

    .branch_flag_o(branch_flag),
    .link_flag_o(link_flag),

    .imm_o(imm_o),

    .read_rs1(read_rs1),
    .read_rs2(read_rs2),
    .rs1_addr(rs1_addr_i),
    .rs2_addr(rs2_addr_i),
    .rd_addr(rd_addr_i),

    .write_reg(write_reg),

    .mem_read(mem_read),
    .mem_write(mem_write),
    .mem_byte_en(mem_byte_en),

    .exception_handle_flag(exception_handle_flag),
    .exception_recover_flag(exception_recover_flag),
    
    .mtvec_data_i(mtvec_data_i),
    .mscratch_data_i(mscratch_data_i),
    .mepc_data_i(mepc_data_i),
    .mcause_data_i(mcause_data_i),
    .mstatus_data_i(mstatus_data_i),
    
    .csr_write_en(csr_write_en),

    .mtvec_data_o(mtvec_data_o),
    .mscratch_data_o(mscratch_data_o),
    .mepc_data_o(mepc_data_o_id),
    .mcause_data_o(mcause_data_o_id),
    .mstatus_data_o(mstatus_data_o_id),

    .mode_cpu(mode_cpu)
);

ex _ex(  // 组合逻辑
    .rst(rst),
    .alu_op_i(alu_op_o),
    .alu_sel_a(alu_sel_a_o),
    .alu_sel_b(alu_sel_b_o),
    
    .pc(pc),
    .pc_now(pc_now),
    .reg_a(rs1_data_o),

    .imm_b(imm_o),
    .reg_b(rs2_data_o),

    .result(ex_result)
);

reg_file _reg_file(
    .clk(clk),
    .rst(rst),
    .read_rs1(read_rs1),
    .read_rs2(read_rs2),
    .write_reg(write_reg_buf), // 写寄存器是时序逻辑
    .rs1_addr(rs1_addr_i), // 读寄存器是组合逻辑
    .rs2_addr(rs2_addr_i),
    .rd_addr(rd_addr_i),
    .rs1_data(rs1_data_i),
    .rs2_data(rs2_data_i),
    .rd_data(rd_data_i)
);

csr_reg _csr_reg(
    .clk(clk),
    .rst(rst),
    
    .csr_write_en(csr_write_en_cpu),
    
    .mtvec_data_o(mtvec_data_i),
    .mscratch_data_o(mscratch_data_i),
    .mepc_data_o(mepc_data_i),
    .mcause_data_o(mcause_data_i),
    .mstatus_data_o(mstatus_data_i),
    
    .mtvec_data_i(mtvec_data_o),
    .mscratch_data_i(mscratch_data_o),
    .mepc_data_i(mepc_data_o),
    .mcause_data_i(mcause_data_o),
    .mstatus_data_i(mstatus_data_o)
);

cpu _cpu(
    .clk(clk),
    .rst(rst),
    
    .done(done),
    .branch_flag_i(branch_flag),
    .link_flag_i(link_flag),
    .write_reg(write_reg),
    
    .ex_result_i(ex_result),
    .ram_data_i(ram_data_i),
    .mem_read(mem_read),
    .mem_write(mem_write),
    .mem_byte_en(mem_byte_en),
    
    .rs1_data_i(rs1_data_o),
    .rs2_data_i(rs2_data_o),

    .io_oen(io_oen),
    .io_wen(io_wen),
    .io_byte_en(io_byte_en),
    .ram_data_o(ram_data_o),

    .address(address),
    .write_reg_buf(write_reg_buf),

    .inst(inst),
    .pc(pc),
    .pc_now(pc_now),
    .rd_data_o(rd_data_i),

    .exception_handle_flag_i(exception_handle_flag),
    .exception_recover_flag_i(exception_recover_flag),

    .csr_write_en_id_cpu(csr_write_en),
    .mepc_data_o_id(mepc_data_o_id),
    .mstatus_data_o_id(mstatus_data_o_id),
    .mcause_data_o_id(mcause_data_o_id),

    .mepc_data_i(mepc_data_i),
    .mstatus_data_i(mstatus_data_i),
    .mtvec_data_i(mtvec_data_i),

    .csr_write_en(csr_write_en_cpu),
    .mepc_data_o(mepc_data_o),
    .mstatus_data_o(mstatus_data_o),
    .mcause_data_o(mcause_data_o),

    .mode_cpu(mode_cpu)
);

endmodule
