`include "rvbl2_defines.vh"

module RISCV_BRANCH_COMP (
    input  [31:0] i_Instruction,
    input  [31:0] i_Op1,
    input  [31:0] i_Op2,
    output        o_Branch
);

    wire [6:0] w_Opcode = i_Instruction[6:0];
    wire [2:0] w_Funct3 = i_Instruction[14:12];


    // As operações de branch são determinadas pelo opcode e funct3 da instrução. 
    // O sinal de saída o_Branch será verdadeiro se a condição de branch for satisfeita 
    // com base nos operandos fornecidos.
    assign o_Branch = (w_Opcode == `OP_BRANCH) && (
        (w_Funct3 == `FUNCT3_BEQ  && i_Op1 == i_Op2) ||
        (w_Funct3 == `FUNCT3_BNE  && i_Op1 != i_Op2) ||
        (w_Funct3 == `FUNCT3_BLT  && $signed(i_Op1) < $signed(i_Op2)) ||
        (w_Funct3 == `FUNCT3_BGE  && $signed(i_Op1) >= $signed(i_Op2)) ||
        (w_Funct3 == `FUNCT3_BLTU && i_Op1 < i_Op2) ||
        (w_Funct3 == `FUNCT3_BGEU && i_Op1 >= i_Op2)
    );

    // As operações BGT, BGTU, BLE e BLEU podem ser implementadas revertendo
    // os operandos e utilizando as operações existentes.
    // Por exemplo, BGT pode ser implementado como BLE com os operandos invertidos