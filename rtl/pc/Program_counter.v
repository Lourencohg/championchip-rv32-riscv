//`timescale 1ns / 1ps

`include "rvbl2_defines.vh"

module program_counter (
    input             i_Clk,
    input             i_Rst,        
    input             i_PC_Write,     // habilita unidade de controle
    input      [1:0]  i_PC_Sel,       // 00=PC+4  01=alvo  10=alvo JALR
    input      [31:0] i_ALU_Result,

    output     [31:0] o_PC,           
    output     [31:0] o_PC_Plus4    
);

    reg [31:0] r_PC;
    reg [31:0] w_PC_Next;

    assign o_PC       = r_PC;
    assign o_PC_Plus4 = r_PC + 32'd4;   // somador dedicado, fora da ULA

//

    always @(*) begin
        case (i_PC_Sel)
            `PC_SRC_PLUS4:  w_PC_Next = o_PC_Plus4;
            `PC_SRC_TARGET: w_PC_Next = i_ALU_Result;
            // JALR: a ISA exige zerar o bit 0, porque rs1 e um registrador de
            // uso geral e pode conter qualquer valor. E a unica diferenca
            // entre esta entrada e PC_SRC_TARGET.
            `PC_SRC_JALR:   w_PC_Next = {i_ALU_Result[31:1], 1'b0};
            // O valor 2'b11 nao e usado por nenhuma instrucao. O default
            // garante atribuicao em todos os caminhos (sem latch) e escolhe a
            // politica mais segura: seguir para a proxima instrucao.
            default:        w_PC_Next = o_PC_Plus4;
        endcase
    end

//

    always @(posedge i_Clk) begin
        if (i_Rst) begin
            // Base da IMEM (Tabela 13 do Block Guide), nao zero.
            r_PC <= `PC_RESET_ADDR;
        end
        else if (i_PC_Write) begin
            r_PC <= w_PC_Next;
        end
        // Sem "else": com i_PC_Write em 0 nenhum ramo atribui e o flip-flop
        // mantem o valor. Em bloco sequencial isso e o comportamento correto
        // de um registrador com habilitacao, e nao infere latch.
    end

endmodule