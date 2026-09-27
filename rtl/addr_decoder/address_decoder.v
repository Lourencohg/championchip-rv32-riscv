`timescale 1ns/1ps
`include "rvbl2_defines.vh"
`default_nettype none

// Combinacional: valida o endereco completo antes de reduzir para indice.
// A LSU valida tamanho/alinhamento e sinaliza esses erros por block_i.
module address_decoder (
    input  wire [31:0] addr_i,
    input  wire [31:0] wdata_i,
    input  wire [3:0]  bw_i,
    input  wire        oe_i,
    input  wire        we_i,
    input  wire        fetch_i,
    input  wire        block_i,
    input  wire [31:0] imem_rdata_i,
    input  wire [31:0] dmem_rdata_i,
    output reg  [19:0] imem_word_addr_o,
    output reg         imem_oe_o,
    output reg  [10:0] dmem_word_addr_o,
    output reg         dmem_oe_o,
    output reg         dmem_we_o,
    output reg  [3:0]  dmem_bw_o,
    output reg  [31:0] dmem_wdata_o,
    output reg  [31:0] rdata_o,
    output reg         decode_fault_o
);
    wire imem_hit = (addr_i >= `IMEM_BASE) && (addr_i <= `IMEM_TOP);
    wire dmem_hit = (addr_i >= `DMEM_BASE) && (addr_i <= `DMEM_TOP);
    wire request_active = oe_i || we_i || fetch_i;
    wire [31:0] imem_offset = addr_i - `IMEM_BASE;
    wire [31:0] dmem_offset = addr_i - `DMEM_BASE;

    always @* begin
        imem_word_addr_o = 20'b0;
        imem_oe_o = 1'b0;
        dmem_word_addr_o = 11'b0;
        dmem_oe_o = 1'b0;
        dmem_we_o = 1'b0;
        dmem_bw_o = 4'b0;
        dmem_wdata_o = 32'b0;
        rdata_o = 32'b0;
        decode_fault_o = 1'b0;

        // block_i impede acesso, mas nao esconde o diagnostico da solicitacao.
        if (request_active) begin
            decode_fault_o = (!imem_hit && !dmem_hit) ||
                             (oe_i && we_i) || (we_i && imem_hit) ||
                             (fetch_i && (!imem_hit || !oe_i || we_i));

            if (!block_i && !decode_fault_o) begin
                if (imem_hit) begin
                    imem_word_addr_o = imem_offset[21:2];
                    imem_oe_o = oe_i;
                    if (oe_i) rdata_o = imem_rdata_i;
                end else if (dmem_hit) begin
                    dmem_word_addr_o = dmem_offset[12:2];
                    dmem_oe_o = oe_i;
                    dmem_we_o = we_i;
                    if (oe_i) rdata_o = dmem_rdata_i;
                    if (we_i) begin
                        dmem_bw_o = bw_i;
                        dmem_wdata_o = wdata_i;
                    end
                end
            end
        end
    end
endmodule

`default_nettype wire
