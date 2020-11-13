`timescale 1ns / 1ps
`include "defines.v"

// ALU模块，组合逻辑
module alu(
    input wire rst,
    input wire[`AluOpWidth-1:0] alu_op_i,

    // 操作数
    input wire[`RegBus] src_a,
    input wire[`RegBus] src_b,

    output reg[`RegBus] result
);

reg cf;
reg zf;
reg sf;
reg vf;

always @(*) begin
    if (rst) begin
        result = `ZERO_WORD;
        {cf, zf, sf, vf} = 4'b0000;
    end else begin
        result = `ZERO_WORD;
        {cf, zf, sf, vf} = 4'b0000;
        case (alu_op_i) 
        `ALU_OP_ADD: begin
            {cf, result} = src_a + src_b;
            vf = src_a[`WordWidth-1] ^ src_b[`WordWidth-1] ^ result[`WordWidth-1] ^ cf;
        end
        `ALU_OP_SUB: begin
            {cf, result} = src_a - src_b;
            vf = src_a[`WordWidth-1] ^ src_b[`WordWidth-1] ^ result[`WordWidth-1] ^ cf;
        end
        `ALU_OP_AND: begin
            result = src_a & src_b;
        end
        `ALU_OP_OR: begin
            result = src_a | src_b;
        end
        `ALU_OP_XOR: begin
            result = src_a ^ src_b;
        end
        `ALU_OP_SLL: begin
            result = src_a << src_b;
        end
        `ALU_OP_SRL: begin
            result = src_a >> src_b;
        end
        `ALU_OP_JALR: begin
            result = (src_a + src_b) & (~32'h0000_0001);
        end
        `ALU_OP_MIN: begin
            result = ( $signed(src_a) < $signed(src_b) ) ? src_a : src_b;
        end
        `ALU_OP_CTZ: begin
            if (~src_a[0]) begin
                result = result + 1;
                if (~src_a[1]) begin
                    result = result + 1;
                    if (~src_a[2]) begin
                        result = result + 1;
                        if (~src_a[3]) begin
                            result = result + 1;
                            if (~src_a[4]) begin
                                result = result + 1;
                                if (~src_a[5]) begin
                                    result = result + 1;
                                    if (~src_a[6]) begin
                                        result = result + 1;
                                        if (~src_a[7]) begin
                                            result = result + 1;
                                            if (~src_a[8]) begin
                                                result = result + 1;
                                                if (~src_a[9]) begin
                                                    result = result + 1;
                                                    if (~src_a[10]) begin
                                                        result = result + 1;
                                                        if (~src_a[11]) begin
                                                            result = result + 1;
                                                            if (~src_a[12]) begin
                                                                result = result + 1;
                                                                if (~src_a[13]) begin
                                                                    result = result + 1;
                                                                    if (~src_a[14]) begin
                                                                        result = result + 1;
                                                                        if (~src_a[15]) begin
                                                                            result = result + 1;
                                                                            if (~src_a[16]) begin
                                                                                result = result + 1;
                                                                                if (~src_a[17]) begin
                                                                                    result = result + 1;
                                                                                    if (~src_a[18]) begin
                                                                                        result = result + 1;
                                                                                        if (~src_a[19]) begin
                                                                                            result = result + 1;
                                                                                            if (~src_a[20]) begin
                                                                                                result = result + 1;
                                                                                                if (~src_a[21]) begin
                                                                                                    result = result + 1;
                                                                                                    if (~src_a[22]) begin
                                                                                                        result = result + 1;
                                                                                                        if (~src_a[23]) begin
                                                                                                            result = result + 1;
                                                                                                            if (~src_a[24]) begin
                                                                                                                result = result + 1;
                                                                                                                if (~src_a[25]) begin
                                                                                                                    result = result + 1;
                                                                                                                    if (~src_a[26]) begin
                                                                                                                        result = result + 1;
                                                                                                                        if (~src_a[27]) begin
                                                                                                                            result = result + 1;
                                                                                                                            if (~src_a[28]) begin
                                                                                                                                result = result + 1;
                                                                                                                                if (~src_a[29]) begin
                                                                                                                                    result = result + 1;
                                                                                                                                    if(~src_a[30]) begin
                                                                                                                                        result =result + 1;
                                                                                                                                        if(~src_a[31]) begin
                                                                                                                                            result =result + 1; 
                                                                                                                                        end
                                                                                                                                    end
                                                                                                                                end
                                                                                                                            end
                                                                                                                        end
                                                                                                                    end
                                                                                                                end
                                                                                                            end
                                                                                                        end
                                                                                                    end
                                                                                                end
                                                                                            end
                                                                                        end
                                                                                    end
                                                                                end
                                                                            end
                                                                        end
                                                                    end
                                                                end
                                                            end
                                                        end
                                                    end
                                                end
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        `ALU_OP_SBCLR: begin
            result = src_a & ~(32'h0000_0001 << (src_b & 31));
        end
        default: begin
            // do nothing
        end
        endcase
        sf = result[`WordWidth-1];
        zf = (result == `ZERO_WORD) ? 1'b1 : 1'b0;
    end
end

endmodule
