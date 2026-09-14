`include "rvbl2_defines.vh"

module instruction_register (
    
    input       i_Clk,
    input       i_Rst,
    input       i_IR_Write, //sinal da unidade de controle
    input       [31:0] i_Mem_data, // 32 bits lidos da memória

    output reg     [31:0] o_IR // Saida da Instrução, i_Instruction na unidade de controle

);

always @(posedge i_Clk) begin
    if (i_Rst) begin

        o_IR <= 32'h00000013;
    
    end else if (i_IR_Write) begin
    
        o_IR <= i_Mem_data;  // Captura a nova instrução no ciclo de Fetch
    
    end
    // Quando i_IR_Write = 0, o IR retém a instrução atual
end

endmodule