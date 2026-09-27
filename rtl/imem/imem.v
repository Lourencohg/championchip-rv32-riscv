`timescale 1ns/1ps
`include "rvbl2_defines.vh"
`default_nettype none

// ROM de palavras: o decodificador converte endereco absoluto em indice local.
// INIT_FILE usa $readmemh: cada entrada representa uma palavra de 32 bits.
module imem #(
    parameter INIT_FILE = ""
) (
    input  wire [19:0] word_addr_i,
    input  wire        oe_i,
    output wire [31:0] rdata_o
);
    localparam WORD_COUNT = (`IMEM_TOP - `IMEM_BASE + 1) / 4;
    reg [31:0] mem [0:WORD_COUNT-1];

    // Sem imagem, conteudo indefinido. Nao inventar instrucoes para lacunas.
    initial begin
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    assign rdata_o = oe_i ? mem[word_addr_i] : 32'b0;
endmodule

`default_nettype wire
