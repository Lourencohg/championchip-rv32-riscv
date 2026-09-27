`timescale 1ns/1ps
`include "rvbl2_defines.vh"
`default_nettype none

// SRAM funcional de 8 KiB, leitura e escrita na borda de subida.
module dmem (
    input  wire        clk_i,
    input  wire        rst_i,
    input  wire [10:0] word_addr_i,
    input  wire        oe_i,
    input  wire        we_i,
    input  wire [3:0]  bw_i,
    input  wire [31:0] wdata_i,
    output reg  [31:0] rdata_o
);
    localparam WORD_COUNT = (`DMEM_TOP - `DMEM_BASE + 1) / 4;
    reg [31:0] mem [0:WORD_COUNT-1];
    integer lane;

    always @(posedge clk_i) begin
        if (rst_i) begin
            // Reset da interface, sem apagar a SRAM.
            rdata_o <= 32'b0;
        end else if (we_i && !oe_i) begin
            for (lane = 0; lane < 4; lane = lane + 1)
                if (bw_i[lane])
                    mem[word_addr_i][8*lane +: 8] <= wdata_i[8*lane +: 8];
        end else if (oe_i && !we_i) begin
            rdata_o <= mem[word_addr_i];
        end
        // Inatividade, escrita ou conflito: reter a saida de leitura.
        // oe_i && we_i e proibido; ambos os acessos ficam bloqueados.
    end
endmodule

`default_nettype wire
