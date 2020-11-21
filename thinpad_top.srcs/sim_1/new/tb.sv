`timescale 1ns / 1ps
module tb;

wire clk_50M, clk_11M0592;

reg clock_btn = 0;         //BTN5手动时钟按钮开关，带消抖电路，按下时为1
reg reset_btn = 0;         //BTN6手动复位按钮开关，带消抖电路，按下时为1

reg[3:0]  touch_btn;  //BTN1~BTN4，按钮开关，按下时为1
reg[31:0] dip_sw;     //32位拨码开关，拨到“ON”时为1

wire[15:0] leds;       //16位LED，输出时1点亮
wire[7:0]  dpy0;       //数码管低位信号，包括小数点，输出1点亮
wire[7:0]  dpy1;       //数码管高位信号，包括小数点，输出1点亮

wire txd;  //直连串口发送端
wire rxd;  //直连串口接收端

wire[31:0] base_ram_data; //BaseRAM数据，低8位与CPLD串口控制器共享
wire[19:0] base_ram_addr; //BaseRAM地址
wire[3:0] base_ram_be_n;  //BaseRAM字节使能，低有效。如果不使用字节使能，请保持为0
wire base_ram_ce_n;       //BaseRAM片选，低有效
wire base_ram_oe_n;       //BaseRAM读使能，低有效
wire base_ram_we_n;       //BaseRAM写使能，低有效

wire[31:0] ext_ram_data; //ExtRAM数据
wire[19:0] ext_ram_addr; //ExtRAM地址
wire[3:0] ext_ram_be_n;  //ExtRAM字节使能，低有效。如果不使用字节使能，请保持为0
wire ext_ram_ce_n;       //ExtRAM片选，低有效
wire ext_ram_oe_n;       //ExtRAM读使能，低有效
wire ext_ram_we_n;       //ExtRAM写使能，低有效

wire [22:0]flash_a;      //Flash地址，a0仅在8bit模式有效，16bit模式无意义
wire [15:0]flash_d;      //Flash数据
wire flash_rp_n;         //Flash复位信号，低有效
wire flash_vpen;         //Flash写保护信号，低电平时不能擦除、烧写
wire flash_ce_n;         //Flash片选信号，低有效
wire flash_oe_n;         //Flash读使能信号，低有效
wire flash_we_n;         //Flash写使能信号，低有效
wire flash_byte_n;       //Flash 8bit模式选择，低有效。在使用flash的16位模式时请设为1

wire uart_rdn;           //读串口信号，低有效
wire uart_wrn;           //写串口信号，低有效
wire uart_dataready;     //串口数据准备好
wire uart_tbre;          //发送数据标志
wire uart_tsre;          //数据发送完毕标志

//Windows需要注意路径分隔符的转义，例如"D:\\foo\\bar.bin"
//parameter BASE_RAM_INIT_FILE = "/tmp/main.bin"; //BaseRAM初始化文件，请修改为实际的绝对路径
parameter BASE_RAM_INIT_FILE = "D:\\supervisor-rv\\kernel\\kernel.bin"; //BaseRAM初始化文件，请修改为实际的绝对路径
parameter EXT_RAM_INIT_FILE = "/tmp/eram.bin";    //ExtRAM初始化文件，请修改为实际的绝对路径
parameter FLASH_INIT_FILE = "/tmp/kernel.elf";    //Flash初始化文件，请修改为实际的绝对路径

assign rxd = 1'b1; //idle state

integer i = 0;//���ڼ���
reg[31:0] fib_addr = 32'h80100000;
reg[31:0] fib_bin[0:29];//fib�����ƴ��룬30��ָ�30*4word=120byte
reg[31:0] read_addr = 32'h80100000;
reg[31:0] read_len = 32'h00000078;

initial begin 
    //$readmemh("D:\\_projects\\vivadoProjects\\cod20-chengzl18\\thinpad_top.srcs\\sim_1\\newfib_hex.txt",fib_bin); 
    //in Little-Endian
    //###### User Program Assembly ######
    //80100000 <_start>:
    fib_bin[0]=32'h93621000;  //ori     t0,zero,1
    // fib_bin[0]=32'h00106293;
    fib_bin[1]=32'h13631000;  //ori     t1,zero,1
    fib_bin[2]=32'h93644000;  //ori     s1,zero,4
    fib_bin[3]=32'h370f4080;  //lui     t5,0x80400
    fib_bin[4]=32'h130fcf7f;  //addi    t5,t5,2044 # 804007fc <__global_pointer$+0x2fef84>
    fib_bin[5]=32'h37054080;  //lui     a0,0x80400
    fib_bin[6]=32'h13050510;  //addi    a0,a0,256 # 80400100 <__global_pointer$+0x2fe888>
    fib_bin[7]=32'hb3836200;  //add     t2,t0,t1
    fib_bin[8]=32'h93620300;  //ori     t0,t1,0
    fib_bin[9]=32'h13e30300;  //ori     t1,t2,0
    fib_bin[10]=32'h23206500;  //sw      t1,0(a0)
    fib_bin[11]=32'h33059500;  //add     a0,a0,s1
    fib_bin[12]=32'h6304e501;  //beq     a0,t5,80100038 <check>
    fib_bin[13]=32'he30400fe;  //beqz    zero,8010001c <_start+0x1c>
    //80100038 <check>:
    fib_bin[14]=32'h93621000;  //ori     t0,zero,1
    fib_bin[15]=32'h13631000;  //ori     t1,zero,1
    fib_bin[16]=32'h37054080;  //lui     a0,0x80400
    fib_bin[17]=32'h13050510;  //addi    a0,a0,256 # 80400100 <__global_pointer$+0x2fe888>
    fib_bin[18]=32'hb3836200;  //add     t2,t0,t1
    fib_bin[19]=32'h93620300;  //ori     t0,t1,0
    fib_bin[20]=32'h13e30300;  //ori     t1,t2,0
    fib_bin[21]=32'h032e0500;  //lw      t3,0(a0)
    fib_bin[22]=32'h6304c301;  //beq     t1,t3,80100060 <check+0x28>
    fib_bin[23]=32'h630c0000;  //beqz    zero,80100074 <end>
    fib_bin[24]=32'h33059500;  //add     a0,a0,s1
    fib_bin[25]=32'h6304e501;  //beq     a0,t5,8010006c <succ>
    fib_bin[26]=32'he30000fe;  //beqz    zero,80100048 <check+0x10>
    //8010006c <succ>:
    fib_bin[27]=32'h13635055;  //ori     t1,zero,1365
    fib_bin[28]=32'h23206500;  //sw      t1,0(a0)
    //80100074 <end>:
    fib_bin[29]=32'h67800000;  //ret


    //在这里可以自定义测试输入序列，例如：
    dip_sw = 32'h2;
    touch_btn = 0;
    reset_btn = 1;
    #100;
    reset_btn = 0;
    // for (integer i = 0; i < 20; i = i+1) begin
    //     #100; //等待100ns
    //     clock_btn = 1; //按下手工时钟按钮
    //     #100; //等待100ns
    //     clock_btn = 0; //松开手工时钟按钮
    // end
    // 模拟PC通过串口发送字符
    // cpld.pc_send_byte(8'h32);
    // #10000;
    // cpld.pc_send_byte(8'h33);

    //XLEN
    cpld.pc_send_byte(8'h57);
    #1000;
    for (i=0; i<30; i=i+1) begin
        //OP_A
        while (uart_dataready) begin
            #1000;
        end; 
        cpld.pc_send_byte(8'h41);
        #1000;

        // 发送用户程序的写入地址 0x80100000，分成4部分发送
        // 第 0 个字节
        while (uart_dataready) begin
            #1000;
        end; 
        cpld.pc_send_byte(fib_addr[7:0]);
        #1000;

        // 第 1 个字节
        while (uart_dataready) begin
            #1000;
        end;
        cpld.pc_send_byte(fib_addr[15:8]);
        #1000;

        // 第 2 个字节
        while (uart_dataready) begin
            #1000;
        end;
        cpld.pc_send_byte(fib_addr[23:16]);
        #1000;

        // 第 3 个字节
        while (uart_dataready) begin
            #1000;
        end;
        cpld.pc_send_byte(fib_addr[31:24]);
        #1000;

        //num=4，分成4部分发送
        while (uart_dataready) begin
            #1000;
        end; 
        cpld.pc_send_byte(8'h04);
        #1000;

        while (uart_dataready) begin
            #1000;
        end;
        cpld.pc_send_byte(8'h00);
        #1000;

        while (uart_dataready) begin
            #1000;
        end;
        cpld.pc_send_byte(8'h00);
        #1000;

        while (uart_dataready) begin
            #1000;
        end;
        cpld.pc_send_byte(8'h00);
        #1000;

        // 读取一个字节
        //�����ֽ�0
        while (uart_dataready) begin
            #1000;
        end;
        // cpld.pc_send_byte(fib_bin[i][7:0]);
        cpld.pc_send_byte(fib_bin[i][31:24]);
        #1000;

        //�����ֽ�1
        while (uart_dataready) begin
            #1000;
        end; 
        // cpld.pc_send_byte(fib_bin[i][15:8]);
        cpld.pc_send_byte(fib_bin[i][23:16]);
        #1000;
        
        //�����ֽ�2
        while (uart_dataready) begin
            #1000;
        end;
        // cpld.pc_send_byte(fib_bin[i][23:16]);
        cpld.pc_send_byte(fib_bin[i][15:8]);
        #1000;
        
        //�����ֽ�3
        while (uart_dataready) begin
            #1000;
        end; 
        // cpld.pc_send_byte(fib_bin[i][31:24]);
        cpld.pc_send_byte(fib_bin[i][7:0]);
        #1000;

        fib_addr = fib_addr+4;
    end

    //runD, 查看0x80100000开始的30 word的数据，也就是上面写入的用户程序代码
    while (uart_dataready) begin
            #1000;
    end; 
    cpld.pc_send_byte(8'h44);
    #1000;

    //��ַ�ֽ�0
    while (uart_dataready) begin
        #1000;
    end; 
    cpld.pc_send_byte(read_addr[7:0]);
    #1000;

    //��ַ�ֽ�1
    while (uart_dataready) begin
        #1000;
    end;
    cpld.pc_send_byte(read_addr[15:8]);
    #1000;

    //��ַ�ֽ�2
    while (uart_dataready) begin
        #1000;
    end;
    cpld.pc_send_byte(read_addr[23:16]);
    #1000;

    //��ַ�ֽ�3
    while (uart_dataready) begin
        #1000;
    end;
    cpld.pc_send_byte(read_addr[31:24]);
    #1000;

    //�����ֽ�0
    while (uart_dataready) begin
        #1000;
    end; 
    cpld.pc_send_byte(read_len[7:0]);
    #1000;

    //�����ֽ�1
    while (uart_dataready) begin
        #1000;
    end;
    cpld.pc_send_byte(read_len[15:8]);
    #1000;

    //�����ֽ�2
    while (uart_dataready) begin
        #1000;
    end;
    cpld.pc_send_byte(read_len[23:16]);
    #1000;

    //�����ֽ�3
    while (uart_dataready) begin
        #1000;
    end;
    cpld.pc_send_byte(read_len[31:24]);
    #1000;

    //runG
    // 执行0x80100000开始的用户程序
    while (uart_dataready) begin
            #1000;
    end; 
    cpld.pc_send_byte(8'h47);
    #1000;

    //��ַ�ֽ�0
    while (uart_dataready) begin
        #1000;
    end; 
    cpld.pc_send_byte(read_addr[7:0]);
    #1000;

    //��ַ�ֽ�1
    while (uart_dataready) begin
        #1000;
    end;
    cpld.pc_send_byte(read_addr[15:8]);
    #1000;

    //��ַ�ֽ�2
    while (uart_dataready) begin
        #1000;
    end;
    cpld.pc_send_byte(read_addr[23:16]);
    #1000;

    //��ַ�ֽ�3
    while (uart_dataready) begin
        #1000;
    end;
    cpld.pc_send_byte(read_addr[31:24]);
    #1000000;
    
end

// 待测试用户设计
thinpad_top dut(
    .clk_50M(clk_50M),
    .clk_11M0592(clk_11M0592),
    .clock_btn(clock_btn),
    .reset_btn(reset_btn),
    .touch_btn(touch_btn),
    .dip_sw(dip_sw),
    .leds(leds),
    .dpy1(dpy1),
    .dpy0(dpy0),
    .txd(txd),
    .rxd(rxd),
    .uart_rdn(uart_rdn),
    .uart_wrn(uart_wrn),
    .uart_dataready(uart_dataready),
    .uart_tbre(uart_tbre),
    .uart_tsre(uart_tsre),
    .base_ram_data(base_ram_data),
    .base_ram_addr(base_ram_addr),
    .base_ram_ce_n(base_ram_ce_n),
    .base_ram_oe_n(base_ram_oe_n),
    .base_ram_we_n(base_ram_we_n),
    .base_ram_be_n(base_ram_be_n),
    .ext_ram_data(ext_ram_data),
    .ext_ram_addr(ext_ram_addr),
    .ext_ram_ce_n(ext_ram_ce_n),
    .ext_ram_oe_n(ext_ram_oe_n),
    .ext_ram_we_n(ext_ram_we_n),
    .ext_ram_be_n(ext_ram_be_n),
    .flash_d(flash_d),
    .flash_a(flash_a),
    .flash_rp_n(flash_rp_n),
    .flash_vpen(flash_vpen),
    .flash_oe_n(flash_oe_n),
    .flash_ce_n(flash_ce_n),
    .flash_byte_n(flash_byte_n),
    .flash_we_n(flash_we_n)
);
// 时钟源
clock osc(
    .clk_11M0592(clk_11M0592),
    .clk_50M    (clk_50M)
);
// CPLD 串口仿真模型
cpld_model cpld(
    .clk_uart(clk_11M0592),
    .uart_rdn(uart_rdn),
    .uart_wrn(uart_wrn),
    .uart_dataready(uart_dataready),
    .uart_tbre(uart_tbre),
    .uart_tsre(uart_tsre),
    .data(base_ram_data[7:0])
);
// BaseRAM 仿真模型
sram_model base1(/*autoinst*/
            .DataIO(base_ram_data[15:0]),
            .Address(base_ram_addr[19:0]),
            .OE_n(base_ram_oe_n),
            .CE_n(base_ram_ce_n),
            .WE_n(base_ram_we_n),
            .LB_n(base_ram_be_n[0]),
            .UB_n(base_ram_be_n[1]));
sram_model base2(/*autoinst*/
            .DataIO(base_ram_data[31:16]),
            .Address(base_ram_addr[19:0]),
            .OE_n(base_ram_oe_n),
            .CE_n(base_ram_ce_n),
            .WE_n(base_ram_we_n),
            .LB_n(base_ram_be_n[2]),
            .UB_n(base_ram_be_n[3]));
// ExtRAM 仿真模型
sram_model ext1(/*autoinst*/
            .DataIO(ext_ram_data[15:0]),
            .Address(ext_ram_addr[19:0]),
            .OE_n(ext_ram_oe_n),
            .CE_n(ext_ram_ce_n),
            .WE_n(ext_ram_we_n),
            .LB_n(ext_ram_be_n[0]),
            .UB_n(ext_ram_be_n[1]));
sram_model ext2(/*autoinst*/
            .DataIO(ext_ram_data[31:16]),
            .Address(ext_ram_addr[19:0]),
            .OE_n(ext_ram_oe_n),
            .CE_n(ext_ram_ce_n),
            .WE_n(ext_ram_we_n),
            .LB_n(ext_ram_be_n[2]),
            .UB_n(ext_ram_be_n[3]));
// Flash 仿真模型
x28fxxxp30 #(.FILENAME_MEM(FLASH_INIT_FILE)) flash(
    .A(flash_a[1+:22]), 
    .DQ(flash_d), 
    .W_N(flash_we_n),    // Write Enable 
    .G_N(flash_oe_n),    // Output Enable
    .E_N(flash_ce_n),    // Chip Enable
    .L_N(1'b0),    // Latch Enable
    .K(1'b0),      // Clock
    .WP_N(flash_vpen),   // Write Protect
    .RP_N(flash_rp_n),   // Reset/Power-Down
    .VDD('d3300), 
    .VDDQ('d3300), 
    .VPP('d1800), 
    .Info(1'b1));

initial begin 
    wait(flash_byte_n == 1'b0);
    $display("8-bit Flash interface is not supported in simulation!");
    $display("Please tie flash_byte_n to high");
    $stop;
end

// 从文件加载 BaseRAM
initial begin 
    reg [31:0] tmp_array[0:1048575];
    integer n_File_ID, n_Init_Size;
    n_File_ID = $fopen(BASE_RAM_INIT_FILE, "rb");
    if(!n_File_ID)begin 
        n_Init_Size = 0;
        $display("Failed to open BaseRAM init file");
    end else begin
        n_Init_Size = $fread(tmp_array, n_File_ID);
        n_Init_Size /= 4;
        $fclose(n_File_ID);
    end
    $display("BaseRAM Init Size(words): %d",n_Init_Size);
    for (integer i = 0; i < n_Init_Size; i++) begin
        base1.mem_array0[i] = tmp_array[i][24+:8];
        base1.mem_array1[i] = tmp_array[i][16+:8];
        base2.mem_array0[i] = tmp_array[i][8+:8];
        base2.mem_array1[i] = tmp_array[i][0+:8];
    end
end

// 从文件加载 ExtRAM
initial begin 
    reg [31:0] tmp_array[0:1048575];
    integer n_File_ID, n_Init_Size;
    n_File_ID = $fopen(EXT_RAM_INIT_FILE, "rb");
    if(!n_File_ID)begin 
        n_Init_Size = 0;
        $display("Failed to open ExtRAM init file");
    end else begin
        n_Init_Size = $fread(tmp_array, n_File_ID);
        n_Init_Size /= 4;
        $fclose(n_File_ID);
    end
    $display("ExtRAM Init Size(words): %d",n_Init_Size);
    for (integer i = 0; i < n_Init_Size; i++) begin
        ext1.mem_array0[i] = tmp_array[i][24+:8];
        ext1.mem_array1[i] = tmp_array[i][16+:8];
        ext2.mem_array0[i] = tmp_array[i][8+:8];
        ext2.mem_array1[i] = tmp_array[i][0+:8];
    end
end
endmodule
