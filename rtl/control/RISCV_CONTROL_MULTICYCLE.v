// RISCV_CONTROL_MULTICYCLE

// DECISOES DE PROJETO:
//    interface com a LSU (Figura 3 do guia):

//    o_Op_Size [2:0] E uma porta fixada pelo guia (op_size_o) e VAI daqui para a LSU. Adotado: passthrough de funct3, que ja codifica tamanho e
//       sinal (000=b 001=h 010=w 100=bu 101=hu). Confirmar a codificacao com quem escrever a LSU - o guia nao publica tabela para este campo.


//    bw_o (byte write) NAO sai daqui. A secao 3.3.2 diz textualmente que "a LSU emite um sinal chamado byte write", e a propria LSU usa os 2
//       bits inferiores do endereco para isso. Nao replicar essa logica aqui.


//    imm_sel tambem nao existe: a secao 3.1.5 diz que o extensor de
//       imediatos decodifica o opcode sozinho.

`timescale 1ns / 1ps

`include "rvbl2_defines.vh"

module RISCV_CONTROL_MULTICYCLE (
    input             i_Clk,
    input             i_Rst,            // reset sincrono ativo em 1
    input      [31:0] i_Instruction,    //saida do IR
    input             i_Branch_Taken,   // comparador de branch

    output reg        o_PC_Write,       // habilita escrita PC
    output reg [1:0]  o_PC_Sel,         // 00=PC+4  01=alvo  10=alvo JALR
    output reg        o_IR_Write,       // captura a instrucao no IR
    output reg        o_Addr_Sel,       // 0=PC  1=saida da ULA
    output reg        o_Mem_Read,       // oe_o
    output reg        o_Mem_Write,      // we_o
    output reg        o_ALU_A_Sel,      // 0=rs1  1=PC <- de onde vai para a ALU
    output reg        o_ALU_B_Sel,      // 0=rs2  1=imediato <- de onde vai para a ALU
    output reg [3:0]  o_ALU_Op,         // Tabela 9 do Block Guide
    output reg [3:0]  o_Mult_Op,        
    output reg [3:0]  o_CRC_Op,         
    output reg [2:0]  o_Result_Sel,     // 0=ULA 1=MULT 2=CRC 3=LSU 4=PC+4
    output reg [2:0]  o_Op_Size,        // op_size_o -> LSU (Figura 3)
    output reg        o_Mult_En,        // habilita o multiplicador
    output reg        o_CRC_En,         // habilita bloco de CRC
    output reg        o_Reg_Write,
    output reg        o_Halt,

    output     [4:0]  o_State           // só para depuracao
);

    // Todas as constantes vem de rvbl2_defines.vh. Nenhuma e redefinida aqui.

    reg [4:0] r_State, w_Next_State;
    assign o_State = r_State;

//----------------------------------------------------------------------------------------------

    // 1. CAMPOS DA INSTRUCAO
    
    wire [6:0] w_Opcode = i_Instruction[6:0];
    wire [2:0] w_Funct3 = i_Instruction[14:12];
    wire [6:0] w_Funct7 = i_Instruction[31:25];
    wire       w_Bit30  = i_Instruction[30];   // funct7[5]
    wire [11:0] w_Funct12 = i_Instruction[31:20]; // separa ECALL de EBREAK


//----------------------------------------------------------------------------------------------
    // CLASSIFICACAO DA INSTRUCAO
    wire w_Is_R      = (w_Opcode == `OP_RTYPE);
    wire w_Is_Mul    = w_Is_R && (w_Funct7 == `F7_MUL);
    wire w_Is_Crc    = w_Is_R && (w_Funct7 == `F7_CRC);
    wire w_Is_Alu_R  = w_Is_R && !w_Is_Mul && !w_Is_Crc;   // <- fallthrough
    wire w_Is_Alu_I  = (w_Opcode == `OP_ITYPE);
    wire w_Is_Load   = (w_Opcode == `OP_LOAD);
    wire w_Is_Store  = (w_Opcode == `OP_STORE);
    wire w_Is_Branch = (w_Opcode == `OP_BRANCH);
    wire w_Is_Jal    = (w_Opcode == `OP_JAL);
    wire w_Is_Jalr   = (w_Opcode == `OP_JALR);
    wire w_Is_Lui    = (w_Opcode == `OP_LUI);
    wire w_Is_Auipc  = (w_Opcode == `OP_AUIPC);
    wire w_Is_System = (w_Opcode == `OP_SYSTEM);
    wire w_Is_Fence  = (w_Opcode == `OP_FENCE);

    wire w_Is_Ecall  = w_Is_System && (w_Funct3 == 3'b000) &&
                       (w_Funct12 == `F12_ECALL);
    wire w_Is_Ebreak = w_Is_System && (w_Funct3 == 3'b000) &&
                       (w_Funct12 == `F12_EBREAK);

    // Politica para opcode ilegal: no-op silencioso que avanca o PC.
    // O guia nao pede trap de instrucao ilegal e a tabela de cobertura das
    // 47 instrucoes nao tem linha para isso.
    wire w_Opcode_Legal = w_Is_R || w_Is_Alu_I || w_Is_Load  || w_Is_Store ||
                          w_Is_Branch || w_Is_Jal || w_Is_Jalr || w_Is_Lui ||
                          w_Is_Auipc  || w_Is_System || w_Is_Fence;


//----------------------------------------------------------------------------------------------
    // Signal decoder "dec" DA PLANILHA
    // Estes valores dependem da instrucao, nao do estado. Sendo calculados uma vez e usados tanto no estado EX quanto no WB 
    
    reg [3:0] w_ALU_Op_Dec;   // "reg" em always @(*) 
    always @(*) begin
        if (w_Is_Lui) begin
            w_ALU_Op_Dec = `ALU_PASS_B;         // LUI: a saida e o proprio imediato
        end
        else if (w_Is_Alu_R || w_Is_Alu_I) begin
            case (w_Funct3)
                // ADD/SUB: o bit 30 so vale para R-type. Em ADDI esse bit faz parte do imediato - se nao houvesse o "w_Is_Alu_R &&", addi com imediato negativo viraria uma subtracao.
                3'b000:  w_ALU_Op_Dec = (w_Is_Alu_R && w_Bit30) ? `ALU_SUB : `ALU_ADD;
                3'b001:  w_ALU_Op_Dec = `ALU_SLL;
                3'b010:  w_ALU_Op_Dec = `ALU_SLT;
                3'b011:  w_ALU_Op_Dec = `ALU_SLTU;
                3'b100:  w_ALU_Op_Dec = `ALU_XOR;
                // SRL/SRA o bit 30 vale para OS DOIS tipos, porque SRAI tambem o usa (o shamt ocupa so 5 bits do imediato).
                3'b101:  w_ALU_Op_Dec = w_Bit30 ? `ALU_SRA : `ALU_SRL;
                3'b110:  w_ALU_Op_Dec = `ALU_OR;
                3'b111:  w_ALU_Op_Dec = `ALU_AND;
                default: w_ALU_Op_Dec = `ALU_ADD;
            endcase
        end
        else begin
            // AUIPC, loads, stores, branches e jumps a ULA sempre soma.
            w_ALU_Op_Dec = `ALU_ADD;
        end
    end

    // Operando A: PC para tudo que e PC-relativo; rs1 para o resto.
    wire w_ALU_A_Dec = (w_Is_Branch || w_Is_Jal || w_Is_Auipc) ? `ALU_SRC_A_PC : `ALU_SRC_A_RS1;

    // Operando B: rs2 so no R-type aritmetico; imediato em todo o resto.
    wire w_ALU_B_Dec = w_Is_Alu_R ? `ALU_SRC_B_RS2 : `ALU_SRC_B_IMM;

    // MULT e CRC: passthrough direto do funct3 (Tabelas 7/10 e 8/11 coincidem
    // por construcao). Nao construa tabela de lookup aqui.
    wire [3:0] w_Mult_Op_Dec = {1'b0, w_Funct3};
    wire [3:0] w_CRC_Op_Dec  = {1'b0, w_Funct3};

    // Fonte do PC nos saltos: JALR precisa da entrada que zera o bit 0.
    wire [1:0] w_PC_Sel_Jump = w_Is_Jalr ? `PC_SRC_JALR : `PC_SRC_TARGET;


//----------------------------------------------------------------------------------------------
    // REGISTRADOR DE ESTADO

    always @(posedge i_Clk) begin
        if (i_Rst) r_State <= `ST_FETCH;
        else       r_State <= w_Next_State;
    end


//----------------------------------------------------------------------------------------------
    // NEXT STATE (combinacional)
    
    always @(*) begin
        w_Next_State = `ST_FETCH;   // default: nenhum caminho fica sem atribuicao
        case (r_State)
            `ST_FETCH: w_Next_State = `ST_DECODE;

            `ST_DECODE: begin
                if      (w_Is_Mul)                  w_Next_State = `ST_EX_MUL;
                else if (w_Is_Crc)                  w_Next_State = `ST_EX_CRC;
                else if (w_Is_Alu_R || w_Is_Alu_I ||
                         w_Is_Lui   || w_Is_Auipc)  w_Next_State = `ST_EX_ALU;
                else if (w_Is_Load  || w_Is_Store)  w_Next_State = `ST_EX_ADDR;
                else if (w_Is_Branch)               w_Next_State = `ST_BRANCH;
                else if (w_Is_Jal   || w_Is_Jalr)   w_Next_State = `ST_JUMP;
                else                                w_Next_State = `ST_SYSTEM;
                
            end

            `ST_EX_ALU:    w_Next_State = `ST_WB_ALU;
            `ST_WB_ALU:    w_Next_State = `ST_FETCH;
            `ST_EX_MUL:    w_Next_State = `ST_WB_MUL;
            `ST_WB_MUL:    w_Next_State = `ST_FETCH;
            `ST_EX_CRC:    w_Next_State = `ST_WB_CRC;
            `ST_WB_CRC:    w_Next_State = `ST_FETCH;

            `ST_EX_ADDR:   w_Next_State = w_Is_Load ? `ST_MEM_READ : `ST_MEM_WRITE;
            `ST_MEM_READ:  w_Next_State = `ST_MEM_CAP;
            `ST_MEM_CAP:   w_Next_State = `ST_WB_LOAD;
            `ST_WB_LOAD:   w_Next_State = `ST_FETCH;
            `ST_MEM_WRITE: w_Next_State = `ST_FETCH;

            `ST_BRANCH:    w_Next_State = `ST_FETCH;
            `ST_JUMP:      w_Next_State = `ST_WB_LINK;
            `ST_WB_LINK:   w_Next_State = `ST_FETCH;

            `ST_SYSTEM:    w_Next_State = (w_Is_Ecall || w_Is_Ebreak) ? `ST_HALT
                                                                     : `ST_FETCH;
            `ST_HALT:      w_Next_State = `ST_HALT;   // terminal, so o reset sai daqui

            default:     w_Next_State = `ST_FETCH;
        endcase
    end


    // SAIDAS  (combinacional, funcao do estado)
    
   
    always @(*) begin
        o_PC_Write   = 1'b0;
        o_PC_Sel     = `PC_SRC_PLUS4;
        o_IR_Write   = 1'b0;
        o_Addr_Sel   = 1'b0;
        o_Mem_Read   = 1'b0;
        o_Mem_Write  = 1'b0;
        o_ALU_A_Sel  = `ALU_SRC_A_RS1;
        o_ALU_B_Sel  = `ALU_SRC_B_RS2;
        o_ALU_Op     = `ALU_ADD;
        o_Mult_Op    = 4'h0;
        o_CRC_Op     = 4'h0;
        o_Result_Sel = `RESULT_SRC_ALU;
        o_Op_Size    = `OP_SIZE_W;
        o_Mult_En    = 1'b0;
        o_CRC_En     = 1'b0;
        o_Reg_Write  = 1'b0;
        o_Halt       = 1'b0;

        case (r_State)

        //---- busca -----------------------------------------------------------
        `ST_FETCH: begin
            o_IR_Write = 1'b1;
            o_Addr_Sel = 1'b0;          // endereco = PC
            o_Mem_Read = 1'b1;
            // [A1] o PC NAO e escrito aqui. A IMEM e ROM combinacional
            // (guia 4.2), entao endereco e instrucao cabem no mesmo ciclo.
        end

        //---- decodificacao ---------------------------------------------------
        `ST_DECODE: begin
            // Leitura de rs1/rs2 e assincrona: nada a habilitar.
        end

        //---- ULA: R-type, I-type, LUI, AUIPC ---------------------------------
        `ST_EX_ALU: begin
            o_ALU_A_Sel = w_ALU_A_Dec;
            o_ALU_B_Sel = w_ALU_B_Dec;
            o_ALU_Op    = w_ALU_Op_Dec;
        end

        `ST_WB_ALU: begin
            o_ALU_A_Sel  = w_ALU_A_Dec;   // [B2] apagar estas tres linhas
            o_ALU_B_Sel  = w_ALU_B_Dec;   // [B2] se existir ALUOut
            o_ALU_Op     = w_ALU_Op_Dec;  // [B2]
            o_Result_Sel = `RESULT_SRC_ALU;
            o_Reg_Write  = 1'b1;
            o_PC_Write   = 1'b1;          // [A1] PC <- PC+4 aqui
            o_PC_Sel     = `PC_SRC_PLUS4;
        end

        //---- multiplicador ---------------------------------------------------
        `ST_EX_MUL: begin
            o_Mult_Op = w_Mult_Op_Dec;
            o_Mult_En = 1'b1;
        end

        `ST_WB_MUL: begin
            o_Mult_Op    = w_Mult_Op_Dec;  // [B2] apagar se existir registrador
            o_Mult_En    = 1'b1;           // [B2] idem
            o_Result_Sel = `RESULT_SRC_MULT;
            o_Reg_Write  = 1'b1;
            o_PC_Write   = 1'b1;
            o_PC_Sel     = `PC_SRC_PLUS4;
        end

        //---- CRC -------------------------------------------------------------
        `ST_EX_CRC: begin
            o_CRC_Op = w_CRC_Op_Dec;
            o_CRC_En = 1'b1;
        end

        `ST_WB_CRC: begin
            o_CRC_Op     = w_CRC_Op_Dec;   // [B2] apagar se existir registrador
            o_CRC_En     = 1'b1;           // [B2] idem
            o_Result_Sel = `RESULT_SRC_CRC;
            o_Reg_Write  = 1'b1;
            o_PC_Write   = 1'b1;
            o_PC_Sel     = `PC_SRC_PLUS4;
        end

        //---- endereco efetivo (load e store) ---------------------------------
        `ST_EX_ADDR: begin
            o_ALU_A_Sel = `ALU_SRC_A_RS1;
            o_ALU_B_Sel = `ALU_SRC_B_IMM;
            o_ALU_Op    = `ALU_ADD;
            o_Op_Size   = w_Funct3;   // ja valido para a LSU
        end

        //---- load: apresenta o endereco --------------------------------------
        `ST_MEM_READ: begin
            o_ALU_A_Sel = `ALU_SRC_A_RS1;    // [B2] os tres selects da ULA precisam
            o_ALU_B_Sel = `ALU_SRC_B_IMM;    // [B2] continuar validos porque
            o_ALU_Op    = `ALU_ADD;  // [B2] o_Addr_Sel=1 le a saida da ULA
            o_Addr_Sel  = 1'b1;
            o_Mem_Read  = 1'b1;
            o_Op_Size   = w_Funct3;
            // DMEM e SRAM sincrona (guia 4.3): o dado ainda nao voltou.
        end

        //---- load: dado valido -----------------------------------------------
        `ST_MEM_CAP: begin
            o_ALU_A_Sel = `ALU_SRC_A_RS1;
            o_ALU_B_Sel = `ALU_SRC_B_IMM;
            o_ALU_Op    = `ALU_ADD;
            o_Addr_Sel  = 1'b1;
            o_Mem_Read  = 1'b1;
            o_Op_Size   = w_Funct3;
            // A LSU faz extracao e extensao a partir de o_Op_Size e addr[1:0].
        end

        //---- load: escreve em rd ---------------------------------------------
        `ST_WB_LOAD: begin
            o_ALU_A_Sel  = `ALU_SRC_A_RS1;   // [B2] sem MDR, o endereco tem de
            o_ALU_B_Sel  = `ALU_SRC_B_IMM;   // [B2] continuar sendo apresentado,
            o_ALU_Op     = `ALU_ADD; // [B2] senao o decodificador de enderecos
            o_Addr_Sel   = 1'b1;      // [B2] chaveia o barramento de volta
            o_Mem_Read   = 1'b1;      // [B2] para a IMEM
            o_Op_Size    = w_Funct3;   // extensao de sinal acontece agora
            o_Result_Sel = `RESULT_SRC_LSU;
            o_Reg_Write  = 1'b1;
            o_PC_Write   = 1'b1;
            o_PC_Sel     = `PC_SRC_PLUS4;
        end

        //---- store -----------------------------------------------------------
        `ST_MEM_WRITE: begin
            o_ALU_A_Sel = `ALU_SRC_A_RS1;
            o_ALU_B_Sel = `ALU_SRC_B_IMM;
            o_ALU_Op    = `ALU_ADD;
            o_Addr_Sel  = 1'b1;
            o_Op_Size   = w_Funct3;   // a LSU deriva bw_o daqui + addr[1:0]
            o_Mem_Write = 1'b1;       // we_o nunca chega a IMEM (guia 4.4)
            o_PC_Write  = 1'b1;
            o_PC_Sel    = `PC_SRC_PLUS4;
        end

        //---- branch ----------------------------------------------------------
        `ST_BRANCH: begin
            o_ALU_A_Sel = `ALU_SRC_A_PC;     // [A1] PC = endereco DA INSTRUCAO
            o_ALU_B_Sel = `ALU_SRC_B_IMM;
            o_ALU_Op    = `ALU_ADD;
            o_PC_Write  = 1'b1;       // [A1] escreve SEMPRE...
            o_PC_Sel    = i_Branch_Taken ? `PC_SRC_TARGET : `PC_SRC_PLUS4;
            // ...e o mux decide entre o alvo e PC+4. Este e o unico estado em
            // que uma saida depende de uma entrada do datapath, e nao so do
            // estado. Branches nao escrevem registrador: o_Reg_Write fica 0.
        end

        //---- jump: calcula o alvo --------------------------------------------
        `ST_JUMP: begin
            o_ALU_A_Sel = w_ALU_A_Dec;  // 01=PC para JAL, 00=rs1 para JALR
            o_ALU_B_Sel = `ALU_SRC_B_IMM;
            o_ALU_Op    = `ALU_ADD;
        end

        //---- jump: grava o retorno e atualiza o PC ---------------------------
        `ST_WB_LINK: begin
            o_ALU_A_Sel  = w_ALU_A_Dec;   // [B2] apagar se existir ALUOut
            o_ALU_B_Sel  = `ALU_SRC_B_IMM;       // [B2]
            o_ALU_Op     = `ALU_ADD;     // [B2]
            o_Result_Sel = `RESULT_SRC_PC4;     // [A1] rd <- PC+4 (somador dedicado)
            o_Reg_Write  = 1'b1;
            o_PC_Write   = 1'b1;
            o_PC_Sel     = w_PC_Sel_Jump; // 01 para JAL, 10 para JALR
        end

        //---- FENCE / ECALL / EBREAK / opcode ilegal --------------------------
        `ST_SYSTEM: begin
            if (w_Is_Ecall || w_Is_Ebreak) begin
                o_PC_Write = 1'b0;    // congela e vai para HALT
            end
            else begin
                // FENCE, opcode ilegal e demais instrucoes do opcode SYSTEM
                // (CSR, fora das 47): no-op que avanca o PC.
                o_PC_Write = 1'b1;
                o_PC_Sel   = `PC_SRC_PLUS4;
            end
        end

        //---- parada ----------------------------------------------------------
        `ST_HALT: begin
            o_Halt = 1'b1;
            // Estado terminal: o testbench de sistema espera por este sinal.
            // Se a firmware oficial de validacao NAO esperar parada no ECALL,
            // troque o destino de `ST_SYSTEM para `ST_FETCH e mantenha o_Halt como
            // flag pegajosa. Ver questao Q3 da planilha.
            // Para tratar EBREAK como no-op em vez de parada, basta remover
            // w_Is_Ebreak das duas condicoes em `ST_SYSTEM.
        end

        default: begin
            // Nenhuma acao: todos os sinais ficam nos defaults acima.
        end

        endcase
    end

endmodule
