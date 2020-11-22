`timescale 1ns / 1ps
`include "defines.v"
// 译码ID阶段
module ctrl(
    input wire rst,
    input wire[`InstBus] inst_i,

    // 来自寄存器的输出
    input wire[`RegBus] rs1_data_i,
    input wire[`RegBus] rs2_data_i,

    // ALU控制信号
    output reg[1:0] alu_sel_a_o,
    output reg[1:0] alu_sel_b_o,
    output reg[`AluOpWidth-1:0] alu_op_o,

    // 送到EX阶段的输??
    output reg[`RegBus] rs1_data_o,
    output reg[`RegBus] rs2_data_o,

    // 送到PC REG的branch信息
    output reg branch_flag_o,

    // 由指令生成立即数
    output reg[`RegBus] imm_o,

    // regfile控制信号
    output reg read_rs1,
    output reg read_rs2,
    output reg[`RegAddrBus] rs1_addr,
    output reg[`RegAddrBus] rs2_addr,
    output reg[`RegAddrBus] rd_addr,
    output reg link_flag_o,

    output reg write_reg,
    // 访存信息
    output reg mem_read,
    output reg mem_write,
    output reg mem_byte_en,

    // 进入异常处理阶段
    output reg exception_handle_flag,
    output reg exception_recover_flag,

    // CSR寄存器控制信号
    input wire[`RegBus] mtvec_data_i,
    input wire[`RegBus] mscratch_data_i,
    input wire[`RegBus] mepc_data_i,
    input wire[`RegBus] mcause_data_i,
    input wire[`RegBus] mstatus_data_i,
    input wire[`RegBus] satp_data_i,
    
    output reg[5:0] csr_write_en,
    output reg[`RegBus] mtvec_data_o,
    output reg[`RegBus] mscratch_data_o,
    output reg[`RegBus] mepc_data_o,
    output reg[`RegBus] mcause_data_o,
    output reg[`RegBus] mstatus_data_o,
    output reg[`RegBus] satp_data_o,

    input wire[1:0] mode_cpu
);

wire[6:0] inst_opcode = inst_i[6:0];
wire[2:0] inst_func3 = inst_i[14:12];
wire[6:0] inst_func7 = inst_i[31:25];
wire[4:0] inst_rs1 = inst_i[19:15];
wire[4:0] inst_rs2 = inst_i[24:20];
wire[4:0] inst_rd = inst_i[11:7];
wire[11:0] inst_csr_addr = inst_i[31:20];

wire[9:0] op = {inst_i[14:12], inst_i[6:0]};

localparam OPCODE_NOP  = 7'b0000000;
localparam OPCODE_AUIPC= 7'b0010111;
localparam OPCODE_JAL  = 7'b1101111;
localparam OPCODE_LUI  = 7'b0110111;
localparam OPCODE_B    = 7'b1100011;
localparam OPCODE_JALR = 7'b1100111;
localparam OPCODE_S    = 7'b0100011;
localparam OPCODE_L    = 7'b0000011;
localparam OPCODE_R    = 7'b0110011;
localparam OPCODE_I    = 7'b0010011;
localparam OPCODE_CSRR = 7'b1110011; // 异常处理

localparam FUNC3_ADD   = 3'b000;
localparam FUNC3_AND   = 3'b111;
localparam FUNC3_XOR   = 3'b100;
localparam FUNC3_OR    = 3'b110;
localparam FUNC3_SLL   = 3'b001;
localparam FUNC3_SRL   = 3'b101;
localparam FUNC3_BEQ   = 3'b000;
localparam FUNC3_BNE   = 3'b001;
localparam FUNC3_LS_W  = 3'b010;
localparam FUNC3_LS_B  = 3'b000;
localparam FUNC3_SCBLR = 3'b001;

localparam FUNC3_CSRRW = 3'b001;
localparam FUNC3_CSRRS = 3'b010;
localparam FUNC3_CSRRC = 3'b011;
localparam FUNC3_E     = 3'b000;

localparam RS2_EBREAK  = 5'b00001;
localparam RS2_ECALL   = 5'b00000;
localparam RS2_MRET    = 5'b00010;

localparam FUNC7_CTZ   = 7'b0110000;
localparam FUNC7_SLL   = 7'b0000000;

localparam FUNC7_MIN   = 7'b0000101;
localparam FUNC7_XOR   = 7'b0000000;

localparam FUNC7_MRET  = 7'b0011000;
localparam FUNC7_SFENCE= 7'b0001001;
localparam FUNC7_E     = 7'b0000000;

localparam CSR_ADDR_MTVEC = 12'h305;
localparam CSR_ADDR_MEPC  = 12'h341;
localparam CSR_ADDR_MCAUSE= 12'h342;
localparam CSR_ADDR_MSCRATCH=12'h340;
localparam CSR_ADDR_MSTATUS=12'h300;
localparam CSR_ADDR_SATP   = 12'h180;

reg csr_en;

// 指令译码，组合�?�辑

// 需要实现的异常检查

// load/store地址, 指令地址不对齐
// 非法指令
// access fault: 地址越界

// 页表相关...

// 出现异常置mcause

always @(*) begin
    if (rst) begin
        {read_rs1, read_rs2} = 2'b00;
        rs1_addr = `ZERO_REG_ADDR;
        rs2_addr = `ZERO_REG_ADDR;
        rd_addr = `ZERO_REG_ADDR;
        {alu_sel_a_o, alu_sel_b_o} = 4'b0000;
        alu_op_o = `ALU_OP_NOP;
        imm_o = `ZERO_WORD;
        branch_flag_o = 1'b0;
        write_reg = 1'b0;
        {mem_read, mem_write} = 2'b00;
        mem_byte_en = 1'b0;
        link_flag_o = 1'b0;
        csr_en = 1'b0;
        csr_write_en = 6'b00_0000;
        exception_handle_flag = 1'b0;
        exception_recover_flag = 1'b0;
        mtvec_data_o = `ZERO_WORD;
        mscratch_data_o = `ZERO_WORD;
        mepc_data_o = `ZERO_WORD;
        mcause_data_o = `ZERO_WORD;
        mstatus_data_o = `ZERO_WORD;
        satp_data_o = `ZERO_WORD;
    end else begin
        {read_rs1, read_rs2} = 2'b00;
        rs1_addr = `ZERO_REG_ADDR;
        rs2_addr = `ZERO_REG_ADDR;
        rd_addr = `ZERO_REG_ADDR;
        {alu_sel_a_o, alu_sel_b_o} = 4'b0000;
        alu_op_o = `ALU_OP_NOP;
        imm_o = `ZERO_WORD;
        branch_flag_o = 1'b0;
        write_reg = 1'b0;
        {mem_read, mem_write} = 2'b00;
        mem_byte_en = 1'b0;
        link_flag_o = 1'b0;
        csr_write_en = 6'b00_0000;
        csr_en = 1'b0;
        exception_handle_flag = 1'b0;
        exception_recover_flag = 1'b0;
        mtvec_data_o = `ZERO_WORD;
        mscratch_data_o = `ZERO_WORD;
        mepc_data_o = `ZERO_WORD;
        mcause_data_o = `ZERO_WORD;
        mstatus_data_o = `ZERO_WORD;
        satp_data_o = `ZERO_WORD;
        case (inst_opcode)
        OPCODE_NOP: begin
            // nop
        end
        OPCODE_R: begin
            read_rs1 = 1'b1; // ??2个寄存器
            read_rs2 = 1'b1;
            write_reg = 1'b1;
            rs1_addr = inst_i[19:15];
            rs2_addr = inst_i[24:20];
            rd_addr = inst_i[11:7];
            alu_sel_a_o = `ALU_SRCA_REGA; // 设置ALU输入来自寄存器a, b
            alu_sel_b_o = `ALU_SRCB_REGB;
            case (inst_func3)
            FUNC3_ADD: begin
                alu_op_o = `ALU_OP_ADD;
            end
            FUNC3_XOR: begin
                case(inst_func7)
                FUNC7_XOR: begin
                    alu_op_o = `ALU_OP_XOR;
                end
                FUNC7_MIN: begin
                    alu_op_o = `ALU_OP_MIN;
                end
                default: begin
                    alu_op_o = `ALU_OP_NOP;
                    exception_handle_flag = 1'b1;
                    csr_write_en[2] = 1'b1;
                    mcause_data_o = {1'b0, 31'b0010}; // 非法指令, 2
                end
                endcase // case inst_func7
            end
            FUNC3_OR: begin
                alu_op_o = `ALU_OP_OR;
            end
            FUNC3_AND: begin
                alu_op_o = `ALU_OP_AND;
            end
            FUNC3_SCBLR: begin
                alu_op_o = `ALU_OP_SBCLR;
            end
            default: begin
                alu_op_o = `ALU_OP_NOP;
                exception_handle_flag = 1'b1;
                csr_write_en[2] = 1'b1;
                mcause_data_o = {1'b0, 31'b0010}; // 非法指令, 2
            end
            endcase  // case inst_func3
        end
        OPCODE_I: begin
            read_rs1 = 1'b1; // ??1个寄存器
            write_reg = 1'b1;
            rs1_addr = inst_i[19:15];
            rs2_addr = inst_i[24:20];
            rd_addr = inst_i[11:7];
            imm_o = {{20{inst_i[31]}}, inst_i[31:20]};  // 符号扩展??32??
            alu_sel_a_o = `ALU_SRCA_REGA; // 设置ALU输入来自寄存器a, b
            alu_sel_b_o = `ALU_SRCB_IMM;
            case(inst_func3)
            FUNC3_ADD: begin
                alu_op_o = `ALU_OP_ADD;
            end
            FUNC3_AND: begin
                alu_op_o = `ALU_OP_AND;
            end
            FUNC3_OR: begin
                alu_op_o = `ALU_OP_OR;
            end
            FUNC3_SLL: begin
                case(inst_func7)
                FUNC7_SLL: begin
                    alu_op_o = `ALU_OP_SLL;
                end
                FUNC7_CTZ: begin
                    alu_op_o = `ALU_OP_CTZ;
                end
                default: begin
                    exception_handle_flag = 1'b1;
                    csr_write_en[2] = 1'b1;
                    mcause_data_o = {1'b0, 31'b0010}; // 非法指令, 2
                end
                endcase  // case inst_func7
            end
            FUNC3_SRL: begin
                alu_op_o = `ALU_OP_SRL;
            end
            default: begin
                exception_handle_flag = 1'b1;
                csr_write_en[2] = 1'b1;
                mcause_data_o = {1'b0, 31'b0010}; // 非法指令, 2
            end
            endcase // case inst_func3
        end
        OPCODE_B: begin
            alu_op_o = `ALU_OP_ADD;
            read_rs1 = 1'b1; // ??2个寄存器
            read_rs2 = 1'b1;
            rs1_addr = inst_i[19:15];
            rs2_addr = inst_i[24:20];
            alu_sel_a_o = `ALU_SRCA_PC; // 设置ALU输入来自PC和IMM
            alu_sel_b_o = `ALU_SRCB_IMM;
            case(inst_func3)
            FUNC3_BEQ: begin
                if (rs1_data_o == rs2_data_o) begin
                    branch_flag_o = 1'b1;
                    imm_o = {{19{inst_i[31]}}, inst_i[31], inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};  // 符号扩展??32??
                end else begin
                    branch_flag_o = 1'b0;
                end
            end
            FUNC3_BNE: begin
                if (rs1_data_o != rs2_data_o) begin
                    branch_flag_o = 1'b1;
                    imm_o = {{19{inst_i[31]}}, inst_i[31], inst_i[7], inst_i[30:25], inst_i[11:8], 1'b0};  // 符号扩展??32??
                end else begin
                    branch_flag_o = 1'b0;
                end
            end
            default: begin
                exception_handle_flag = 1'b1;
                csr_write_en[2] = 1'b1;
                mcause_data_o = {1'b0, 31'b0010}; // 非法指令, 2
            end
            endcase // case inst_func3
        end
        OPCODE_S: begin
            alu_op_o = `ALU_OP_ADD;
            read_rs1 = 1'b1; // 读rs1和rs2
            read_rs2 = 1'b1;
            mem_write = 1'b1;
            rs1_addr = inst_i[19:15];
            rs2_addr = inst_i[24:20];
            alu_sel_a_o = `ALU_SRCA_REGA; // 设置ALU输入来自寄存器a, b
            alu_sel_b_o = `ALU_SRCB_IMM;
            imm_o = {{20{inst_i[31]}}, inst_i[31:25], inst_i[11:7]};  // 符号扩展??32??
            case(inst_func3)
            FUNC3_LS_W: begin
                // blank here
            end
            FUNC3_LS_B: begin
                mem_byte_en = 1'b1;
            end
            default: begin  // blank here
                exception_handle_flag = 1'b1;
                csr_write_en[2] = 1'b1;
                mcause_data_o = {1'b0, 31'b0010}; // 非法指令, 2
            end
            endcase // case inst_func3
        end
        OPCODE_L: begin
            alu_op_o = `ALU_OP_ADD;
            read_rs1 = 1'b1; // 只读rs1
            write_reg = 1'b1;
            mem_read = 1'b1;
            rs1_addr = inst_i[19:15];
            rd_addr = inst_i[11:7];
            alu_sel_a_o = `ALU_SRCA_REGA; // 设置ALU输入来自寄存器a, b
            alu_sel_b_o = `ALU_SRCB_IMM;
            imm_o = {{20{inst_i[31]}}, inst_i[31:20]};  // 符号扩展??32??
            case(inst_func3)
            FUNC3_LS_W: begin
                // blank here
            end
            FUNC3_LS_B: begin
                mem_byte_en = 1'b1;
            end
            default: begin
                exception_handle_flag = 1'b1;
                csr_write_en[2] = 1'b1;
                mcause_data_o = {1'b0, 31'b0010}; // 非法指令, 2
            end
            endcase // case inst_func3
        end
        OPCODE_AUIPC: begin // auipc rd, imm
            alu_op_o = `ALU_OP_ADD;
            write_reg = 1'b1;
            imm_o = {inst_i[31:12], 12'b0000_0000_0000};  // 符号扩展??32??
            rd_addr = inst_i[11:7];
            alu_sel_a_o = `ALU_SRCA_PC; // 设置ALU输入来自寄存器a, b
            alu_sel_b_o = `ALU_SRCB_IMM;
        end
        OPCODE_LUI: begin // lui 
            alu_op_o = `ALU_OP_ADD;
            rs1_addr = `ZERO_REG_ADDR;
            read_rs1 = 1'b1; // ??1个寄存器
            write_reg = 1'b1;
            imm_o = {inst_i[31:12], 12'b0000_0000_0000};  // 符号扩展??32??
            rd_addr = inst_i[11:7];
            alu_sel_a_o = `ALU_SRCA_REGA; // 设置ALU输入来自寄存器a, b
            alu_sel_b_o = `ALU_SRCB_IMM;
        end
        OPCODE_JAL: begin // jal rd, imm
            alu_op_o = `ALU_OP_ADD;
            write_reg = 1'b1;
            rd_addr = inst_i[11:7];
            alu_sel_a_o = `ALU_SRCA_PC; // 设置ALU输入来自PC和IMM
            alu_sel_b_o = `ALU_SRCB_IMM;
            branch_flag_o = 1'b1;
            link_flag_o = 1'b1;
            imm_o = {{12{inst_i[31]}}, inst_i[31], inst_i[19:12], inst_i[20], inst_i[30:21], 1'b0};  // 符号扩展??32??
        end
        OPCODE_JALR: begin // jalr
            alu_op_o = `ALU_OP_JALR;
            read_rs1 = 1'b1; // ??1个寄存器
            rs1_addr = inst_i[19:15];
            write_reg = 1'b1;
            rd_addr = inst_i[11:7];
            alu_sel_a_o = `ALU_SRCA_REGA; // 设置ALU输入来自PC和IMM
            alu_sel_b_o = `ALU_SRCB_IMM;
            branch_flag_o = 1'b1;
            link_flag_o = 1'b1;
            imm_o = {{20{inst_i[31]}}, inst_i[31:20]};  // 符号扩展??32??
        end
        OPCODE_CSRR: begin
            csr_en = 1'b1;
            rs1_addr = inst_i[19:15];
            read_rs1 = 1'b1; // ??1个寄存器
            rd_addr = inst_i[11:7];
            alu_sel_a_o = `ALU_SRCA_REGA; // 设置ALU输入来自PC和IMM
            alu_sel_b_o = `ALU_SRCB_IMM;
            imm_o = `ZERO_WORD;
            alu_op_o = `ALU_OP_ADD; // rs1_data_o + 0 = rs1_data_o
            case (inst_func3)
            FUNC3_CSRRW: begin
                // 写使能信号
                write_reg = 1'b1;
                case(inst_csr_addr)
                CSR_ADDR_SATP: begin
                    csr_write_en[5] = 1'b1;
                    satp_data_o = rs1_data_i;
                end
                CSR_ADDR_MTVEC: begin
                    csr_write_en[4] = 1'b1;
                    mtvec_data_o = rs1_data_i;
                end
                CSR_ADDR_MEPC: begin
                    csr_write_en[3] = 1'b1;
                    mepc_data_o = rs1_data_i;
                end
                CSR_ADDR_MCAUSE: begin
                    csr_write_en[2] = 1'b1;
                    mcause_data_o = rs1_data_i;
                end
                CSR_ADDR_MSCRATCH: begin
                    csr_write_en[1] = 1'b1;
                    mscratch_data_o = rs1_data_i;
                end
                CSR_ADDR_MSTATUS: begin
                    csr_write_en[0] = 1'b1;
                    mstatus_data_o = rs1_data_i;
                end
                default: begin
                    exception_handle_flag = 1'b1;
                    csr_write_en = 5'b00100;
                    mcause_data_o = {1'b0, 31'b0010}; // 非法指令, 2
                end
                endcase // case inst_csr_addr
            end
            FUNC3_CSRRS: begin
                // 写使能信号
                write_reg = 1'b1;
                case(inst_csr_addr)
                CSR_ADDR_SATP: begin
                    csr_write_en[5] = 1'b1;
                    satp_data_o = rs1_data_i | satp_data_i;
                end
                CSR_ADDR_MTVEC: begin
                    csr_write_en[4] = 1'b1;
                    mtvec_data_o = rs1_data_i | mtvec_data_i;
                end
                CSR_ADDR_MEPC: begin
                    csr_write_en[3] = 1'b1;
                    mepc_data_o = rs1_data_i | mepc_data_i;
                end
                CSR_ADDR_MCAUSE: begin
                    csr_write_en[2] = 1'b1;
                    mcause_data_o = rs1_data_i | mcause_data_i;
                end
                CSR_ADDR_MSCRATCH: begin
                    csr_write_en[1] = 1'b1;
                    mscratch_data_o = rs1_data_i | mscratch_data_i;
                end
                CSR_ADDR_MSTATUS: begin
                    csr_write_en[0] = 1'b1;
                    mstatus_data_o = rs1_data_i | mstatus_data_i;
                end
                default: begin
                    csr_write_en = 6'b000100;
                    exception_handle_flag = 1'b1;
                    mcause_data_o = {1'b0, 31'b0010}; // 非法指令, 2
                end
                endcase  // case inst_csr_addr
            end
            FUNC3_CSRRC: begin
                // 写使能信号
                write_reg = 1'b1;
                case(inst_csr_addr)
                CSR_ADDR_SATP: begin
                    csr_write_en[5] = 1'b1;
                    satp_data_o = (~rs1_data_i) & satp_data_i;
                end
                CSR_ADDR_MTVEC: begin
                    csr_write_en[4] = 1'b1;
                    mtvec_data_o = (~rs1_data_i) & mtvec_data_i;
                end
                CSR_ADDR_MEPC: begin
                    csr_write_en[3] = 1'b1;
                    mepc_data_o = (~rs1_data_i) & mepc_data_i;
                end
                CSR_ADDR_MCAUSE: begin
                    csr_write_en[2] = 1'b1;
                    mcause_data_o = (~rs1_data_i) & mcause_data_i;
                end
                CSR_ADDR_MSCRATCH: begin
                    csr_write_en[1] = 1'b1;
                    mscratch_data_o = (~rs1_data_i) & mscratch_data_i;
                end
                CSR_ADDR_MSTATUS: begin
                    csr_write_en[0] = 1'b1;
                    mstatus_data_o = (~rs1_data_i) & mstatus_data_i;
                end
                default: begin
                    csr_write_en = 6'b000100;
                    exception_handle_flag = 1'b1;
                    mcause_data_o = {1'b0, 31'b0010}; // 非法指令, 2
                end
                endcase // case inst_csr_addr
            end
            FUNC3_E: begin
                write_reg = 1'b0;
                case(inst_func7)
                FUNC7_MRET: begin
                    exception_handle_flag = 1'b1;
                    exception_recover_flag = 1'b1; // 从机器模式返回
                end
                FUNC7_SFENCE: begin
                    // nop
                    exception_handle_flag = 1'b0;
                    csr_write_en = 6'b000000;
                end
                FUNC7_E: begin
                    exception_handle_flag = 1'b1;
                    csr_write_en[2] = 1'b1;
                    case(inst_rs2)
                    RS2_ECALL: begin
                        mcause_data_o = (mode_cpu == `MODE_U) ? {1'b0, 31'b1000} : {1'b0, 31'b1011};
                    end
                    RS2_EBREAK: begin
                        mcause_data_o = {1'b0, 31'b0011}; // 断点异常, 3
                    end
                    default: begin
                        mcause_data_o = {1'b0, 31'b0010}; // 非法指令, 2
                    end
                    endcase // case inst_rs2
                end
                default: begin
                    write_reg = 1'b0;
                    exception_handle_flag = 1'b1;
                    csr_write_en[2] = 1'b1;
                    mcause_data_o = {1'b0, 31'b0010}; // 非法指令, 2
                end
                endcase // case inst_func7
            end
            default: begin
                exception_handle_flag = 1'b1;
                csr_write_en[2] = 1'b1;
                mcause_data_o = {1'b0, 31'b0010}; // 非法指令, 2
            end
            endcase // case inst_func3
        end
        default: begin
            exception_handle_flag = 1'b1;
            csr_write_en[2] = 1'b1;
            mcause_data_o = {1'b0, 31'b0010}; // 非法指令, 2
        end
        endcase // case inst_opcode
    end
end

// 确定A寄存器数??
always @(*) begin
    if (rst) begin
        rs1_data_o = `ZERO_WORD;
    end else if (csr_en == 1'b1) begin
        case(inst_csr_addr)
        CSR_ADDR_MTVEC: begin
            rs1_data_o = mtvec_data_i;
        end
        CSR_ADDR_MEPC: begin
            rs1_data_o = mepc_data_i;
        end
        CSR_ADDR_MCAUSE: begin
            rs1_data_o = mcause_data_i;
        end
        CSR_ADDR_MSCRATCH: begin
            rs1_data_o = mscratch_data_i;
        end
        CSR_ADDR_MSTATUS: begin
            rs1_data_o = mstatus_data_i;
        end
        CSR_ADDR_SATP: begin
            rs1_data_o = satp_data_i;
        end
        default: begin
            rs1_data_o = `ZERO_WORD;
        end
        endcase
    end else if (read_rs1 == 1'b1) begin
        rs1_data_o = rs1_data_i;
    end else begin
        rs1_data_o = `ZERO_WORD;
    end
end

// 确定B寄存器数??
always @(*) begin
    if (rst) begin
        rs2_data_o = `ZERO_WORD;
    end else if (read_rs2 == 1'b1) begin
        rs2_data_o = rs2_data_i;
    end else begin
        rs2_data_o = `ZERO_WORD;
    end
end

endmodule
