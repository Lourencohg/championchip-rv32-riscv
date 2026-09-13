//==============================================================================
// rvbl2_defines.vh
//
// Arquivo de constantes compartilhado do nucleo RVBL-2 (RV32I_Zmmul_Xicrc).
// ChampionCHIP eXperience 2026 - Fase 2.
//
// REGRA DE USO: este arquivo e a UNICA fonte de verdade para qualquer numero
// que atravesse a fronteira entre dois modulos. Nenhum modulo deve redefinir
// estes valores como localparam proprio. Constantes usadas dentro de um unico
// modulo continuam sendo localparam la dentro - nao poluir este arquivo.
//
// Todo modulo comeca com:   `include "rvbl2_defines.vh"
//
// ORIGEM DE CADA BLOCO:
//   - Opcodes / funct3 / funct7 : RISC-V Unprivileged ISA + Tabelas 7 e 8
//   - Selecao da ULA            : Tabela 9  do Block Guide
//   - Selecao do multiplicador  : Tabela 10 do Block Guide
//   - Selecao do CRC            : Tabela 11 do Block Guide
//   - Mapa de memoria           : Tabela 13 do Block Guide
//   - Muxes, estados, op_size   : decisoes da equipe (marcadas com [DECISAO])
//
// Alterar qualquer valor aqui muda o projeto inteiro de uma vez. Alteracoes
// devem ser combinadas com os quatro donos de modulo antes do commit.
//
//   Gabriel : ULA, Multiplicador, CRC
//   Felipe  : Banco de Registradores, Extensor de Imediatos, Comparador
//   Lourenco: Unidade de Controle, PC, IR, topo
//   Maia    : LSU, IMEM, DMEM, Decodificador de Enderecos
//==============================================================================

`ifndef RVBL2_DEFINES_VH
`define RVBL2_DEFINES_VH

//==============================================================================
// 1. OPCODES  (instrucao[6:0])
//==============================================================================
// ATENCAO: OP_RTYPE e compartilhado por TRES familias. Ver secao 2.
`define OP_RTYPE    7'b0110011  // R-type aritmetico + Zmmul + Xicrc
`define OP_ITYPE    7'b0010011  // aritmetico com imediato
`define OP_LOAD     7'b0000011
`define OP_STORE    7'b0100011
`define OP_BRANCH   7'b1100011
`define OP_JAL      7'b1101111
`define OP_JALR     7'b1100111
`define OP_LUI      7'b0110111
`define OP_AUIPC    7'b0010111
`define OP_SYSTEM   7'b1110011  // ECALL / EBREAK
`define OP_FENCE    7'b0001111

//==============================================================================
// 2. funct7 - desambiguacao do opcode 0110011
//==============================================================================
// ADD, MUL e CRCB tem opcode 0110011 E funct3 000 identicos. So o funct7
// separa os tres. Quem decodificar isto deve testar MUL e CRC primeiro e
// deixar o R-type aritmetico como ELSE - testar "funct7 == 0000000" quebra
// SUB e SRA, que usam 0100000.
`define F7_BASE     7'b0000000  // ADD, SLL, SLT, SLTU, XOR, SRL, OR, AND, SLLI, SRLI
`define F7_ALT      7'b0100000  // SUB, SRA, SRAI
`define F7_MUL      7'b0000001  // extensao Zmmul
`define F7_CRC      7'b1000000  // extensao Xicrc

// Bit 30 da instrucao = funct7[5]. Distingue ADD/SUB e SRL/SRA.
// ARMADILHA: em SRLI/SRAI este bit VALE (tipo I, mas o shamt usa so 5 bits).
// Em ADDI, SLTI, XORI, ORI, ANDI ele e parte do imediato e deve ser IGNORADO.
`define BIT_ALT_OP  30

//==============================================================================
// 3. funct3
//==============================================================================
// -- Aritmeticas (valem para R-type e I-type) ---------------------------------
`define F3_ADD_SUB  3'b000      // ADD  SUB  ADDI
`define F3_SLL      3'b001      // SLL  SLLI
`define F3_SLT      3'b010      // SLT  SLTI
`define F3_SLTU     3'b011      // SLTU SLTIU
`define F3_XOR      3'b100      // XOR  XORI
`define F3_SR       3'b101      // SRL  SRA  SRLI  SRAI
`define F3_OR       3'b110      // OR   ORI
`define F3_AND      3'b111      // AND  ANDI

// -- Loads --------------------------------------------------------------------
`define F3_LB       3'b000
`define F3_LH       3'b001
`define F3_LW       3'b010
`define F3_LBU      3'b100
`define F3_LHU      3'b101

// -- Stores -------------------------------------------------------------------
`define F3_SB       3'b000
`define F3_SH       3'b001
`define F3_SW       3'b010

// -- Branches -----------------------------------------------------------------
// O comparador de branch (Felipe) recebe este campo diretamente.
`define F3_BEQ      3'b000
`define F3_BNE      3'b001
`define F3_BLT      3'b100
`define F3_BGE      3'b101
`define F3_BLTU     3'b110
`define F3_BGEU     3'b111

// -- Zmmul (com F7_MUL) --------------------------------------------------------
`define F3_MUL      3'b000
`define F3_MULH     3'b001
`define F3_MULHSU   3'b010
`define F3_MULHU    3'b011

// -- Xicrc (com F7_CRC) --------------------------------------------------------
`define F3_CRCB     3'b000
`define F3_CRCH     3'b001
`define F3_CRCW     3'b010

//==============================================================================
// 4. funct12 - separa ECALL de EBREAK  (instrucao[31:20], com OP_SYSTEM)
//==============================================================================
`define F12_ECALL   12'h000
`define F12_EBREAK  12'h001

//==============================================================================
// 5. SELECAO DA ULA  (alu_op, 4 bits) - Tabela 9
//==============================================================================
// NAO usar a numeracao do exemplo RISCV_CONTROL do ChipInventor, que e outra.
`define ALU_PASS_B  4'h0        // Q = B. Unico usuario: LUI.
`define ALU_ADD     4'h1
`define ALU_SUB     4'h2
`define ALU_AND     4'h3
`define ALU_OR      4'h4
`define ALU_XOR     4'h5
`define ALU_SLL     4'h6
`define ALU_SRL     4'h7
`define ALU_SRA     4'h8
`define ALU_SLT     4'h9
`define ALU_SLTU    4'hA

//==============================================================================
// 6. SELECAO DO MULTIPLICADOR  (mult_op, 4 bits) - Tabela 10
//==============================================================================
// Por construcao estes valores coincidem com o funct3 da Tabela 7: o seletor
// pode ser ligado como {1'b0, funct3}. Nao montar tabela de lookup.
`define MULT_MUL    4'h0        // rd = (rs1_s  * rs2_s )[31:0]
`define MULT_MULH   4'h1        // rd = (rs1_s  * rs2_s )[63:32]
`define MULT_MULHSU 4'h2        // rd = (rs1_s  * rs2_u )[63:32]
`define MULT_MULHU  4'h3        // rd = (rs1_u  * rs2_u )[63:32]

//==============================================================================
// 7. SELECAO DO CRC  (crc_op, 4 bits) - Tabela 11
//==============================================================================
// Mesma coincidencia com o funct3 da Tabela 8.
`define CRC_CRCB    4'h0        // CRC de 8 bits
`define CRC_CRCH    4'h1        // CRC de 16 bits
`define CRC_CRCW    4'h2        // CRC de 32 bits

//==============================================================================
// 8. MUXES DO DATAPATH   [DECISAO DA EQUIPE]
//==============================================================================
// Nenhum destes valores vem do Block Guide. Sao contrato interno entre a
// unidade de controle (Lourenco) e o datapath (Felipe / Gabriel).

// -- Operando A da ULA --------------------------------------------------------
// [DECISAO] 1 bit. Uma terceira entrada com a constante zero foi considerada
// e descartada: nenhuma das 47 instrucoes a usa (LUI foi resolvido com
// ALU_PASS_B). Se a entrada zero voltar, isto passa a 2 bits e alu_src_a
// muda de largura em TODOS os modulos.
`define ALU_SRC_A_RS1    1'b0
`define ALU_SRC_A_PC     1'b1   // branches, JAL e AUIPC

// -- Operando B da ULA --------------------------------------------------------
// [DECISAO] 1 bit, valido sob a Decisao A1 (ver secao 9). Sob A2 ou A3 seria
// preciso reintroduzir uma entrada com a constante 4, e este campo voltaria
// a ter 2 bits.
`define ALU_SRC_B_RS2    1'b0   // so R-type aritmetico
`define ALU_SRC_B_IMM    1'b1   // todo o resto

// -- Fonte do PC --------------------------------------------------------------
`define PC_SRC_PLUS4     2'b00  // saida do somador dedicado de +4
`define PC_SRC_TARGET    2'b01  // saida da ULA (branch tomado, JAL)
`define PC_SRC_JALR      2'b10  // saida da ULA com o bit 0 zerado (exigido pela ISA)

// -- Mux de write-back --------------------------------------------------------
// RESULT_SRC_PC4 e o MESMO fio de PC_SRC_PLUS4: o somador dedicado. Sob a
// Decisao A1 o endereco de retorno do JAL/JALR e PC+4, nao o PC.
`define RESULT_SRC_ALU   3'b000
`define RESULT_SRC_MULT  3'b001
`define RESULT_SRC_CRC   3'b010
`define RESULT_SRC_LSU   3'b011
`define RESULT_SRC_PC4   3'b100

// -- Fonte do endereco de memoria ---------------------------------------------
`define ADDR_SRC_PC      1'b0   // busca de instrucao
`define ADDR_SRC_ALU     1'b1   // load / store

//==============================================================================
// 9. op_size - unidade de controle -> LSU   [DECISAO DA EQUIPE]
//==============================================================================
// A porta op_size_o [2:0] e fixada pela Figura 3 do Block Guide, mas a
// codificacao NAO e publicada. [DECISAO] passthrough puro do funct3, que ja
// codifica tamanho e sinal. Tamanho em [1:0], extensao de zeros em [2].
// A LSU deriva o byte write a partir daqui e dos 2 bits inferiores do
// endereco (secao 3.3.2) - bw_o NAO sai da unidade de controle.
`define OP_SIZE_B        3'b000 // LB  / SB
`define OP_SIZE_H        3'b001 // LH  / SH
`define OP_SIZE_W        3'b010 // LW  / SW
`define OP_SIZE_BU       3'b100 // LBU
`define OP_SIZE_HU       3'b101 // LHU

//==============================================================================
// 10. ESTADOS DA MAQUINA  (5 bits)   [DECISAO DA EQUIPE]
//==============================================================================
// Uso interno da unidade de controle. Ficam aqui porque o testbench de
// verificacao independente (Felipe) precisa referenciar os estados por nome.
`define ST_FETCH      5'd0
`define ST_DECODE     5'd1
`define ST_EX_ALU     5'd2
`define ST_WB_ALU     5'd3
`define ST_EX_MUL     5'd4
`define ST_WB_MUL     5'd5
`define ST_EX_CRC     5'd6
`define ST_WB_CRC     5'd7
`define ST_EX_ADDR    5'd8
`define ST_MEM_READ   5'd9
`define ST_MEM_CAP    5'd10
`define ST_WB_LOAD    5'd11
`define ST_MEM_WRITE  5'd12
`define ST_BRANCH     5'd13
`define ST_JUMP       5'd14
`define ST_WB_LINK    5'd15
`define ST_SYSTEM     5'd16
`define ST_HALT       5'd17

// Contagem de ciclos por classe (para o relatorio e para o testbench):
//   ALU / MUL / CRC / LUI / AUIPC ... 4 ciclos
//   load ....................... 6 ciclos
//   store ...................... 4 ciclos
//   branch ..................... 3 ciclos
//   jump (JAL / JALR) .......... 4 ciclos

//==============================================================================
// 11. MAPA DE MEMORIA - Tabela 13
//==============================================================================
`define IMEM_BASE     32'h00400000  // ROM de 4 MB
`define IMEM_TOP      32'h007FFFFF
`define DMEM_BASE     32'h10010000  // SRAM de 8 kB
`define DMEM_TOP      32'h10011FFF

// Valor do PC apos o reset: primeira instrucao do firmware.
`define PC_RESET_ADDR `IMEM_BASE

//==============================================================================
// 12. DECISOES DE ARQUITETURA REGISTRADAS
//==============================================================================
// Nao geram macro, mas todo modulo depende delas. Mudanca aqui = mudanca em
// mais de um modulo ao mesmo tempo.
//
// [A1] O PC guarda o endereco DA INSTRUCAO durante toda a execucao dela.
//      Nao e incrementado na busca; e escrito no ultimo estado de cada
//      instrucao. Um somador dedicado de +4 (fora da ULA) alimenta
//      PC_SRC_PLUS4 e RESULT_SRC_PC4.
//      Motivo: no RISC-V o alvo e PC_da_instrucao + imediato. Incrementar na
//      busca erraria o alvo em 4 bytes nos 6 branches, no JAL e no AUIPC.
//
// [B1] NAO existem registradores intermediarios (ALUOut / MDR). O caminho
//      execute -> write-back e combinacional, portanto a unidade de controle
//      MANTEM os seletores da ULA, do multiplicador, do CRC e da memoria
//      durante os estados de write-back.
//      Consequencia para Gabriel: a saida da ULA, do multiplicador e do CRC
//      NAO deve ser registrada.
//      Consequencia para Maia: a LSU nao registra o dado do load; o endereco
//      continua sendo apresentado durante o write-back.
//
// [C]  bw_o e gerado pela LSU (secao 3.3.2), nao pela unidade de controle.
//
// [D]  Nao existe sinal imm_sel: o extensor de imediatos decodifica o opcode
//      sozinho (secao 3.1.5). Contrato de Felipe.
//
// [E]  x0 e protegido dentro do banco de registradores (secao 3.1.4). A
//      unidade de controle afirma reg_write sem verificar rd. Contrato de
//      Felipe.
//
// [F]  Opcode ilegal: no-op silencioso que avanca o PC. O guia nao pede trap
//      de instrucao ilegal.
//
// [G]  ECALL e EBREAK levam o nucleo ao estado de parada (halt). A confirmar
//      quando a firmware oficial de validacao for publicada - se ela nao
//      esperar parada, revisar.
//
// [PENDENTE] Temporizacao da IMEM. A busca ocupa UM estado por assumir que a
//      IMEM e ROM combinacional. O guia afirma que a DMEM e sincrona
//      (secao 4.3) e nao diz o mesmo da IMEM (secao 4.2) - e inferencia, nao
//      fato. Confirmar com Maia. Se a IMEM for sincrona, a busca passa a
//      ocupar dois estados e TODAS as contagens de ciclo da secao 10 mudam.

`endif // RVBL2_DEFINES_VH
