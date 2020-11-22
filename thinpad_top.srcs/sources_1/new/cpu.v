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
    
    output reg[`RegBus] address,
    output wire write_reg_buf,

    output reg[`InstBus] inst,
    output reg[`RegBus] pc,
    output reg[`RegBus] pc_now,
    output reg[`RegBus] rd_data_o,

    // 译码阶段给出的异常处理写入信息
    input wire exception_handle_flag_i,
    input wire exception_recover_flag_i,
    input wire[6:0] csr_write_en_id_cpu,
    input wire[`RegBus] mepc_data_o_id,
    input wire[`RegBus] mstatus_data_o_id,
    input wire[`RegBus] mcause_data_o_id,
    input wire[`RegBus] mtval_data_o_id,

    // 来自异常寄存器模块的数据
    input wire[`RegBus] mepc_data_i,
    input wire[`RegBus] mstatus_data_i,
    input wire[`RegBus] mtvec_data_i,
    input wire[`RegBus] satp_data_i,

    // 给异常寄存器模块的输入
    output wire[6:0] csr_write_en,
    output reg[`RegBus] mepc_data_o,
    output reg[`RegBus] mstatus_data_o,
    output reg[`RegBus] mcause_data_o,
    output reg[`RegBus] mtval_data_o,

    output reg[1:0] mode_cpu // 当前模式
);

localparam STAGE_IDLE              = 5'b11111;
localparam STAGE_IF_BEGIN          = 5'b00000;
localparam STAGE_IF_FINISH         = 5'b00001;
localparam STAGE_ID                = 5'b00010;
localparam STAGE_EX                = 5'b00011;
localparam STAGE_MEM_BEGIN         = 5'b00100;
localparam STAGE_MEM_FINISH        = 5'b00101;
localparam STAGE_SET_RD            = 5'b11001;
localparam STAGE_WB                = 5'b00110;
localparam STAGE_EXCEPTION_HANDLE  = 5'b00111;
// 页表相关
// 取指
localparam STAGE_IF_PAGE_1_BEGIN   = 5'b01001;
localparam STAGE_IF_PAGE_1_FINISH  = 5'b01010;
localparam STAGE_IF_PAGE_2_BEGIN   = 5'b01011;
localparam STAGE_IF_PAGE_2_FINISH  = 5'b01100;
localparam STAGE_IF_PAGE_3_BEGIN   = 5'b01101;
localparam STAGE_IF_PAGE_3_FINISH  = 5'b01110;
// 访存
localparam STAGE_MEM_PAGE_1_BEGIN  = 5'b01111;
localparam STAGE_MEM_PAGE_1_FINISH = 5'b10000;
localparam STAGE_MEM_PAGE_2_BEGIN  = 5'b10001;
localparam STAGE_MEM_PAGE_2_FINISH = 5'b10010;
localparam STAGE_MEM_PAGE_3_BEGIN  = 5'b10011;
localparam STAGE_MEM_PAGE_3_FINISH = 5'b10100;
// TLB阶段
localparam STAGE_IF_TLB_WRITE      = 5'b11000;
localparam STAGE_MEM_TLB_WRITE     = 5'b10111;

wire is_if_page = (mode_cpu == `MODE_U) & satp_data_i[31];    // 取指使用页表
wire is_mem_page = (mode_cpu == `MODE_U) & satp_data_i[31]; // 访存使用页表

reg[4:0] state;

reg[6:0] csr_write_en_cpu;

assign write_reg_buf = (state == STAGE_WB) ? write_reg : 1'b0;
assign csr_write_en = (state == STAGE_WB) ? (csr_write_en_id_cpu | csr_write_en_cpu) : 7'b000_0000;

// 地址相关异常判断
wire address_misalign = (ex_result_i < 32'h1000_0000 || (ex_result_i > 32'h1000_0005 && ex_result_i < 32'h8000_0000) || ex_result_i > 32'h807F_FFFF);
wire access_fault = ex_result_i[1:0] != 2'b00;

wire if_access_fault = (pc < 32'h8000_0000 || pc > 32'h807F_FFFF);
wire if_address_misalign = pc[1:0] != 2'b00;

wire load_access_fault = mem_read && address_misalign;
wire load_address_misalign = mem_read && access_fault;

wire store_access_fault = mem_write && address_misalign;
wire store_address_misalign = mem_write && access_fault;

reg exception_handle_flag_cpu;

// TLB相关
reg[32:0] tlb_regs[0:127];
wire[12:0] pc_tlb_vpn_prefix = pc[31:19];
wire[6:0] pc_tlb_index = pc[18:12];
wire[12:0] mem_tlb_vpn_prefix = ex_result_i[31:19];
wire[6:0] mem_tlb_index = ex_result_i[18:12];

always @(posedge clk) begin
    if (rst) begin
        {io_oen, io_wen, io_byte_en} <= 3'b110;
        pc <= `PC_INIT_ADDR;
        address <= `ZERO_WORD;
        pc_now <= `PC_INIT_ADDR;
        inst <= `ZERO_WORD;
        rd_data_o <= `ZERO_WORD;
        ram_data_o <= `ZERO_WORD;
        mepc_data_o <= `ZERO_WORD;
        mstatus_data_o <= `ZERO_WORD;
        mtval_data_o <= `ZERO_WORD;
        mcause_data_o <= `ZERO_WORD;
        state <= STAGE_IDLE;
        csr_write_en_cpu <= 7'b0000000;
        exception_handle_flag_cpu <= 1'b0;
        mode_cpu <= `MODE_M;
    end else begin
        case (state)
        STAGE_IDLE: begin
            if (is_if_page == 1'b1) begin
                // tlb判断, 注意TLB表的项将来可能还会加长，以加入控制信息
                if (tlb_regs[pc_tlb_index][32:20] == pc_tlb_vpn_prefix) begin
                    address <= {tlb_regs[pc_tlb_index][19:0], pc[11:0]};
                    state <= STAGE_IF_PAGE_3_BEGIN;
                end else begin // tlb miss
                    address <= {satp_data_i[19:0], pc[31:22], 2'b00};
                    state <= STAGE_IF_PAGE_1_BEGIN;
                end
            end else begin
                address <= pc;
                state <= STAGE_IF_BEGIN;
            end
        end
        STAGE_IF_BEGIN: begin
            pc_now <= pc;
            if (if_access_fault == 1'b1) begin
                csr_write_en_cpu[2] = 1'b1;
                csr_write_en_cpu[6] = 1'b1;
                mtval_data_o <= pc;
                mcause_data_o <= {1'b0, 31'b0001}; // 取指access fault, 1
                state <= STAGE_EXCEPTION_HANDLE;
                exception_handle_flag_cpu <= 1'b1;
            end else if (if_address_misalign == 1'b1) begin
                csr_write_en_cpu[2] = 1'b1;
                csr_write_en_cpu[6] = 1'b1;
                mtval_data_o <= pc;
                mcause_data_o <= {1'b0, 31'b0000}; // 取指address misalign, 0
                state <= STAGE_EXCEPTION_HANDLE;
                exception_handle_flag_cpu <= 1'b1;
            end else begin
                io_oen <= 1'b0; // 读内存模式
                csr_write_en_cpu <= 7'b0000000;
                state <= STAGE_IF_FINISH;
                exception_handle_flag_cpu <= 1'b0;
            end
        end
        STAGE_IF_FINISH: begin
            if (done) begin // busy-waiting for instruction
                {io_oen, io_wen, io_byte_en} <= 3'b110;
                inst <= ram_data_i; // 取出指令
                state <= STAGE_ID;
            end
        end
        STAGE_IF_PAGE_1_BEGIN: begin
            io_oen <= 1'b0; // 读内存模式
            csr_write_en_cpu <= 7'b0000000;
            exception_handle_flag_cpu <= 1'b0;
            state <= STAGE_IF_PAGE_1_FINISH;
        end
        STAGE_IF_PAGE_1_FINISH: begin
            if (done) begin
                io_oen <= 1'b1;
                address <= {ram_data_i[29:10], pc[21:12], 2'b00};
                state <= STAGE_IF_PAGE_2_BEGIN;
            end
        end
        STAGE_IF_PAGE_2_BEGIN: begin
            io_oen <= 1'b0; // 读内存模式
            state <= STAGE_IF_PAGE_2_FINISH;
        end
        STAGE_IF_PAGE_2_FINISH: begin // 运行到这里说明TLB MISS
            if (done) begin
                io_oen <= 1'b1;
                address <= {ram_data_i[29:10], pc[11:0]};
                state <= STAGE_IF_TLB_WRITE;
            end
        end
        STAGE_IF_TLB_WRITE: begin
            tlb_regs[pc_tlb_index] <= {pc_tlb_vpn_prefix, address[31:12]}; // 更新TLB
            state <= STAGE_IF_PAGE_3_BEGIN;
        end
        STAGE_IF_PAGE_3_BEGIN: begin
            io_oen <= 1'b0; // 读内存模式
            state <= STAGE_IF_PAGE_3_FINISH;
        end
        STAGE_IF_PAGE_3_FINISH: begin
            if (done) begin
                io_oen <= 1'b1;
                inst <= ram_data_i; // 取出指令
                state <= STAGE_ID;
            end
        end
        STAGE_ID: begin // 控制信息都在一个周期内给出
            state <= STAGE_EX;
        end
        // 在访存前进行异常处理
        STAGE_EX: begin  // 运算结果在一个周期内给出
            if (exception_handle_flag_i == 1'b1) begin
                state <= STAGE_EXCEPTION_HANDLE;
            end else begin
                if (is_mem_page == 1'b1) begin
                    // tlb判断, 注意TLB表的项将来可能还会加长，以加入控制信息
                    if (tlb_regs[mem_tlb_index][32:20] == mem_tlb_vpn_prefix) begin
                        address <= {tlb_regs[mem_tlb_index][19:0], ex_result_i[11:0]};
                        state <= STAGE_MEM_PAGE_3_BEGIN;
                    end else begin // tlb miss
                        address <= {satp_data_i[19:0], ex_result_i[31:22], 2'b00}; 
                        state <= STAGE_MEM_PAGE_1_BEGIN;
                    end
                end else begin
                    address <= ex_result_i;
                    state <= STAGE_MEM_BEGIN;
                end
            end
            mepc_data_o <= mepc_data_o_id;
            mstatus_data_o <= mstatus_data_o_id;
            mcause_data_o <= mcause_data_o_id;
            mtval_data_o <= mtval_data_o_id;
        end
        STAGE_EXCEPTION_HANDLE: begin
            if (exception_recover_flag_i == 1'b1) begin // mret
                pc <= mepc_data_i;
                mode_cpu <= mstatus_data_i[12:11]; // U-mode
            end else begin // ebreak, ecall
                mepc_data_o <= pc;
                pc <= mtvec_data_i;
                mstatus_data_o <= {mstatus_data_i[31:13], mode_cpu, mstatus_data_i[10:0]}; // M-mode
                mode_cpu <= `MODE_M;
                csr_write_en_cpu <= 7'b0001001; // mepc, mstatus
            end
            state <= STAGE_WB;
        end
        STAGE_MEM_BEGIN: begin
            if (load_access_fault) begin
                csr_write_en_cpu[2] = 1'b1;
                csr_write_en_cpu[6] = 1'b1;
                mtval_data_o <= ex_result_i;
                mcause_data_o <= {1'b0, 31'b0101}; // load access fault, 5
                exception_handle_flag_cpu <= 1'b1;
                state <= STAGE_EXCEPTION_HANDLE;
            end else if (load_address_misalign && (~mem_byte_en)) begin
                csr_write_en_cpu[2] = 1'b1;
                csr_write_en_cpu[6] = 1'b1;
                mtval_data_o <= ex_result_i;
                mcause_data_o <= {1'b0, 31'b0100}; // load address misalign, 4
                exception_handle_flag_cpu <= 1'b1;
                state <= STAGE_EXCEPTION_HANDLE;
            end else if (store_access_fault) begin
                csr_write_en_cpu[2] = 1'b1;
                csr_write_en_cpu[6] = 1'b1;
                mtval_data_o <= ex_result_i;
                mcause_data_o <= {1'b0, 31'b0111}; // store access fault, 7
                exception_handle_flag_cpu <= 1'b1;
                state <= STAGE_EXCEPTION_HANDLE;
            end else if (store_address_misalign && (~mem_byte_en)) begin
                csr_write_en_cpu[2] = 1'b1;
                csr_write_en_cpu[6] = 1'b1;
                mtval_data_o <= ex_result_i;
                mcause_data_o <= {1'b0, 31'b0110}; // store address misalign, 6
                exception_handle_flag_cpu <= 1'b1;
                state <= STAGE_EXCEPTION_HANDLE;
            end else begin
                if (mem_read == 1'b1) begin
                    io_oen <= 1'b0;
                    io_byte_en <= mem_byte_en;
                    state <= STAGE_MEM_FINISH;
                end else if (mem_write == 1'b1) begin
                    io_wen <= 1'b0;
                    ram_data_o <= rs2_data_i;
                    io_byte_en <= mem_byte_en;
                    state <= STAGE_MEM_FINISH;
                end else begin
                    state <= STAGE_SET_RD;
                end
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
        STAGE_MEM_PAGE_1_BEGIN: begin
            if ((~mem_read) & (~mem_write)) begin
                state <= STAGE_SET_RD;
            end else begin
                io_oen <= 1'b0;
                state <= STAGE_MEM_PAGE_1_FINISH;
            end
        end
        STAGE_MEM_PAGE_1_FINISH: begin
            if (done) begin
                io_oen <= 1'b1;
                address <= {ram_data_i[29:10], ex_result_i[21:12], 2'b00}; 
                state <= STAGE_MEM_PAGE_2_BEGIN;
            end
        end
        STAGE_MEM_PAGE_2_BEGIN: begin
            io_oen <= 1'b0;
            state <= STAGE_MEM_PAGE_2_FINISH;
        end
        STAGE_MEM_PAGE_2_FINISH: begin
            if (done) begin
                io_oen <= 1'b1;
                address <= {ram_data_i[29:10], ex_result_i[11:0]};
                state <= STAGE_MEM_TLB_WRITE;
            end
        end
        STAGE_MEM_TLB_WRITE: begin
            tlb_regs[mem_tlb_index] <= {mem_tlb_vpn_prefix, address[31:12]}; // 更新TLB
            state <= STAGE_MEM_PAGE_3_BEGIN;
        end
        STAGE_MEM_PAGE_3_BEGIN: begin
            if (mem_read == 1'b1) begin
                io_oen <= 1'b0;
                io_byte_en <= mem_byte_en;
                state <= STAGE_MEM_PAGE_3_FINISH;
            end else if (mem_write == 1'b1) begin
                io_wen <= 1'b0;
                ram_data_o <= rs2_data_i;
                io_byte_en <= mem_byte_en;
                state <= STAGE_MEM_PAGE_3_FINISH;
            end else begin
                state <= STAGE_SET_RD;
            end
        end
        STAGE_MEM_PAGE_3_FINISH: begin
            if (done) begin
                {io_oen, io_wen, io_byte_en} <= 3'b110;
                state <= STAGE_WB;
                if (mem_read) begin
                    rd_data_o <= ram_data_i; // 取出读到的值
                end
            end
        end
        STAGE_SET_RD: begin
            if (link_flag_i) begin
                rd_data_o <= pc + 4;
            end else begin
                rd_data_o <= ex_result_i;
            end
            state <= STAGE_WB;
        end
        // 写回阶段完成通用寄存器和异常寄存器的写回
        STAGE_WB: begin
            if (branch_flag_i == 1'b1 && exception_handle_flag_i == 1'b0) begin // 更新PC
                pc <= ex_result_i;
            end else if (exception_handle_flag_i == 1'b0 && exception_handle_flag_cpu == 1'b0) begin
                pc <= pc + 4;
            end
            state <= STAGE_IDLE;
        end
        endcase
    end
end

endmodule
