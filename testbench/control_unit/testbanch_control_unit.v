`timescale 1ns/1ps

module testbench;

reg i_Clk = 0;
reg i_Rst = 0;
reg [31:0] i_Instruction = 0;
reg i_Branch_Taken = 0;
wire o_Addr_Sel;
wire o_Mem_Read;
wire o_Mem_Write;
wire [1:0] o_ALU_A_Sel;
wire [1:0] o_ALU_B_Sel;
wire [3:0] o_ALU_Op;
wire [3:0] o_Mult_Op;
wire [3:0] o_CRC_Op;
wire [2:0] o_Result_Sel;
wire [2:0] o_OP_Size;
wire o_Mult_En;
wire o_CRC_En;
wire o_Reg_Write;
wire o_Halt;
wire [4:0] o_State;
reg [31:0] i_ALU_Result = 0;
reg [31:0] i_Mem_data = 0;
wire [31:0] o_PC;
wire [31:0] o_PC_Plus4;
wire [31:0] o_IR;

top ai45 (
    .i_Clk(i_Clk), .i_Rst(i_Rst),
    .i_Instruction(i_Instruction), .i_Branch_Taken(i_Branch_Taken),
    .o_Addr_Sel(o_Addr_Sel), .o_Mem_Read(o_Mem_Read),
    .o_Mem_Write(o_Mem_Write), .o_ALU_A_Sel(o_ALU_A_Sel),
    .o_ALU_B_Sel(o_ALU_B_Sel), .o_ALU_Op(o_ALU_Op),
    .o_Mult_Op(o_Mult_Op), .o_CRC_Op(o_CRC_Op),
    .o_Result_Sel(o_Result_Sel), .o_OP_Size(o_OP_Size),
    .o_Mult_En(o_Mult_En), .o_CRC_En(o_CRC_En),
    .o_Reg_Write(o_Reg_Write), .o_Halt(o_Halt), .o_State(o_State),
    .i_ALU_Result(i_ALU_Result), .i_Mem_data(i_Mem_data),
    .o_PC(o_PC), .o_PC_Plus4(o_PC_Plus4), .o_IR(o_IR)
);

always #5 i_Clk = ~i_Clk;

integer tests = 0;
integer passed = 0;
integer failed = 0;
integer k;
reg [31:0] saved_ir;
reg [31:0] saved_pc;

localparam FETCH=0,      DECODE=1,   EX_ALU=2,   WB_ALU=3,
           EX_MUL=4,     WB_MUL=5,   EX_CRC=6,   WB_CRC=7,
           EX_ADDR=8,    MEM_READ=9, MEM_CAP=10, WB_LOAD=11,
           MEM_WRITE=12, BRANCH=13,  JUMP=14,    WB_LINK=15,
           SYSTEM=16,    HALT=17;

localparam ALU_PASS_B=0, ALU_ADD=1,  ALU_SUB=2,  ALU_AND=3,
           ALU_OR=4,     ALU_XOR=5,  ALU_SLL=6,  ALU_SRL=7,
           ALU_SRA=8,    ALU_SLT=9,  ALU_SLTU=10;
//-------------------------------------------------------------------
// Rotina de teste de certa condição 
// -> Checa se certa expressão é verdadeira ou falsa e 
//    imprime no terminal o resultado  
//	condition - espressão a ser avaliada;
//	message   - mensagem a ser escrita no terminal no sucesso 
//                 ou falha
task check;
    input condition;
    input [8*100-1:0] message;
    begin
        tests = tests + 1;
        if (condition === 1'b1) begin
            passed = passed + 1;
            $display("[PASS] %0s", message);
        end else begin
            failed = failed + 1;
            $display("[FAIL] %0s | state=%0d PC=%08h IR=%08h",
                     message, o_State, o_PC, o_IR);
        end
    end
endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
// Rotina de temporização
// -> Faz com que depois de uma borda de subida a simulação espere
//    por 1 unidade de tempo. (usado para garantir que o FSM passou  
//    de estado)
task tick;
    begin
        @(posedge i_Clk); #1;
    end
endtask
//-------------------------------------------------------------------
  
//-------------------------------------------------------------------
// Rotina de aplicação do reset no DUT
// -> Aplica os sinais de reset no FSM e retorna os estados dos  
//    sinais importantes para o padrão.
task reset_dut;
    begin
        @(negedge i_Clk);
        i_Rst = 1'b1;
        i_Instruction = 32'h00000013; // NOP
        i_Branch_Taken = 1'b0;
        i_ALU_Result = 32'h00000000;
        i_Mem_data = 32'h00000013;
        tick;
        @(negedge i_Clk);
        i_Rst = 1'b0;
        #1;
    end
endtask
//-------------------------------------------------------------------

//-------------------------------------------------------------------
// Rotina que coloca o controlador em FETCH e verifica 
// a interface básica
// -> Reseta o FSM e garante que ele esteja no ponto de executar a
//    instrução capturada, pois essa rotina passa pelo FETCH e DECODE
//    que devem acontecer para qualquer instrução.    
//	instruction: instrução a ser executada pelo FSM.
task begin_instruction;
    input [31:0] instruction;
    begin
        reset_dut;
        i_Instruction = instruction;
        #1;
        check(o_State == FETCH, "Estado FETCH apos reset");
        check(o_Mem_Read == 1'b1 && o_Addr_Sel == 1'b0,
              "FETCH: leitura da memoria de instrucao");
        check(o_PC == 32'h00400000, "PC reinicia em 0x00400000");
        check(o_PC_Plus4 == 32'h00400004, "PC+4 apos reset");
        tick; // FETCH -> DECODE
        check(o_State == DECODE, "Transicao FETCH -> DECODE");
        tick; // DECODE -> estado de execucao
    end
endtask
//-------------------------------------------------------------------



//-------------------------------------------------------------------
// Rotina para analisar a instrução ligada ao ALU
// -> Recebe os campos func3, o bit30 e se a instrução é R_type
//    e retorna a instrução do ALU certa a ser acionada.
function [3:0] expected_alu;
    input [2:0] f3;
    input bit30;
    input is_r;
    begin
        case (f3)
          3'b000: expected_alu = (is_r && bit30) ? ALU_SUB : ALU_ADD;
          3'b001: expected_alu = ALU_SLL;
          3'b010: expected_alu = ALU_SLT;
          3'b011: expected_alu = ALU_SLTU;
          3'b100: expected_alu = ALU_XOR;
          3'b101: expected_alu = bit30 ? ALU_SRA : ALU_SRL;
          3'b110: expected_alu = ALU_OR;
          3'b111: expected_alu = ALU_AND;
        endcase
    end
endfunction
//-------------------------------------------------------------------
  
initial begin
    $dumpfile("testbench.vcd");
    $dumpvars(0, testbench);
  
	//---------------------------------------------------------------
    // Checa se o sistema começa do estado inical esperado
    reset_dut;
    check(o_State == FETCH, "Reset coloca FSM em FETCH");
    check(o_PC == 32'h00400000, "Reset do PC");
    check(o_IR == 32'h00000013, "Reset do IR para NOP");
    check(o_PC_Plus4 == 32'h00400004, "Somador PC+4");
	//---------------------------------------------------------------
  
  	//---------------------------------------------------------------
    // Checa se IR está capturando o dado da memória e se
    // IR retem o dado fora do estado FETCH como é para contecer
  	// quando o FSM tira o sinal de escrita do IR.
    i_Mem_data = 32'h12345678;
    tick; // FETCH -> DECODE, a captura ocorreu na borda anterior em FETCH
    check(o_IR == 32'h12345678, "IR captura i_Mem_data durante FETCH");
    saved_ir = o_IR;
    i_Mem_data = 32'h87654321;
    tick;
    check(o_IR == saved_ir, "IR retém dado quando i_IR_Write=0");
	//---------------------------------------------------------------
  
  	//---------------------------------------------------------------
    // Teste sistemático dos 8 funct3 de ALU R-type.
  	// Passa por todas as possibilidades de instruções ligadas à ALU
    // e checa o fluxo de estados do FSM.
    for (k=0; k<8; k=k+1) begin
        begin_instruction({7'b0000000,5'd2,5'd1,k[2:0],5'd3,7'b0110011});
        check(o_State == EX_ALU, "R-type chega a EX_ALU");
        check(o_ALU_Op == expected_alu(k[2:0],1'b0,1'b1),
              "R-type: decodificacao de funct3");
        check(o_ALU_A_Sel == 2'b00 && o_ALU_B_Sel == 2'b00,
              "R-type: operandos rs1 e rs2");
        tick;
        check(o_State == WB_ALU && o_Reg_Write && 1'b1,
              "LOAD: WB_LOAD e escrita de registrador");
        tick;
    end
  	//---------------------------------------------------------------

  	//---------------------------------------------------------------
    // R-type SUB e SRA: bit 30 influencia a operação.
  	// Checa se as instruções não contempladas no último FOR
  	// são reconhecidas.
    begin_instruction({7'b0100000,5'd2,5'd1,3'b000,5'd3,7'b0110011});
    check(o_State == EX_ALU && o_ALU_Op == ALU_SUB, "R-type SUB via bit30");
    tick; check(o_State == WB_ALU && o_Reg_Write, "SUB escreve rd"); tick;

    begin_instruction({7'b0100000,5'd2,5'd1,3'b101,5'd3,7'b0110011});
    check(o_State == EX_ALU && o_ALU_Op == ALU_SRA, "R-type SRA via bit30");
    tick; check(o_State == WB_ALU && o_Reg_Write, "SRA escreve rd"); tick;
	//---------------------------------------------------------------
   	
  	//---------------------------------------------------------------
  	// Os 8 funct3 de I-type, incluindo o caso de imediato 
  	// em ADDI.
  	// Checa se as instruções I-Type estão sendo reconhecidas de 
  	// forma correta.
  	for (k=0; k<8; k=k+1) begin
        begin_instruction({12'h800,5'd1,k[2:0],5'd3,7'b0010011});
        check(o_State == EX_ALU, "I-type chega a EX_ALU");
        check(o_ALU_Op == expected_alu(k[2:0],1'b0,1'b0) ||
              (k==5 && o_ALU_Op==ALU_SRL),
              "I-type: decodificacao de funct3");
        check(o_ALU_A_Sel == 2'b00 && o_ALU_B_Sel == 2'b01,
              "I-type: rs1 e imediato");
        tick; check(o_State == WB_ALU && o_Reg_Write, "I-type write-back"); tick;
    end
  	
    
  	begin_instruction({12'h800,5'd1,3'b000,5'd3,7'b0010011});
    check(o_ALU_Op == ALU_ADD, "ADDI com imediato negativo continua ADD");
    tick; tick;

    begin_instruction({12'h400,5'd1,3'b101,5'd3,7'b0010011});
    check(o_State == EX_ALU && o_ALU_Op == ALU_SRA,
          "SRAI reconhecido pelo bit 30");
    tick; check(o_State == WB_ALU && o_Reg_Write, "SRAI write-back"); tick;
	
    // LUI e AUIPC.
    begin_instruction({20'h12345,5'd3,7'b0110111});
    check(o_State == EX_ALU && o_ALU_Op == ALU_PASS_B,
          "LUI usa PASS_B");
    tick; check(o_State == WB_ALU && o_Reg_Write, "LUI write-back"); tick;

    begin_instruction({20'h12345,5'd3,7'b0010111});
    check(o_State == EX_ALU && o_ALU_A_Sel == 2'b01 &&
          o_ALU_B_Sel == 2'b01 && o_ALU_Op == ALU_ADD,
          "AUIPC usa PC + imediato");
    tick; check(o_State == WB_ALU && o_Reg_Write, "AUIPC write-back"); tick;
	//---------------------------------------------------------------
  	
  	//---------------------------------------------------------------
    // Multiplicação: funct7=0000001 e todos os funct3 possíveis.
    // Checa se as instruções de multiplicação estão sendo 
    // reconhecidas.
    for (k=0; k<8; k=k+1) begin
        begin_instruction({7'b0000001,5'd2,5'd1,k[2:0],5'd3,7'b0110011});
        check(o_State == EX_MUL && o_Mult_En && o_Mult_Op == {1'b0,k[2:0]},
              "MUL: estado EX, enable e funct3");
        tick;
        check(o_State == WB_MUL && o_Mult_En &&
              o_Result_Sel == 3'd1 && o_Reg_Write,
              "MUL: write-back e selecao do resultado");
        tick;
    end
  	//---------------------------------------------------------------

  	//---------------------------------------------------------------
    // CRC: funct7=1000000 e todos os funct3 possíveis.
  	// Checa se as instruções de CRC estão sendo reconhecidas.
    for (k=0; k<8; k=k+1) begin
        begin_instruction({7'b1000000,5'd2,5'd1,k[2:0],5'd3,7'b0110011});
        check(o_State == EX_CRC && o_CRC_En && o_CRC_Op == {1'b0,k[2:0]},
              "CRC: estado EX, enable e funct3");
        tick;
        check(o_State == WB_CRC && o_CRC_En &&
              o_Result_Sel == 3'd2 && o_Reg_Write,
              "CRC: write-back e selecao do resultado");
        tick;
    end
	//---------------------------------------------------------------
  
  	//---------------------------------------------------------------
    // Loads: funct3 000,001,010,100,101; ciclo por ciclo.
  	// Checa se as instruções de LOAD estão sendo reconhecidas.
    for (k=0; k<5; k=k+1) begin
        case (k)
          0: begin_instruction({12'd4,5'd1,3'b000,5'd3,7'b0000011});
          1: begin_instruction({12'd4,5'd1,3'b001,5'd3,7'b0000011});
          2: begin_instruction({12'd4,5'd1,3'b010,5'd3,7'b0000011});
          3: begin_instruction({12'd4,5'd1,3'b100,5'd3,7'b0000011});
          4: begin_instruction({12'd4,5'd1,3'b101,5'd3,7'b0000011});
        endcase
        check(o_State == EX_ADDR && o_ALU_B_Sel == 2'b01 &&
              o_OP_Size == i_Instruction[14:12], "LOAD: calcula endereco e tamanho");
        tick; check(o_State == MEM_READ && o_Mem_Read && o_Addr_Sel,
                    "LOAD: estado MEM_READ");
        tick; check(o_State == MEM_CAP && o_Mem_Read && o_Addr_Sel,
                    "LOAD: estado MEM_CAP");
        tick; check(o_State == WB_LOAD && o_Reg_Write &&
                    o_Result_Sel == 3'd3 && 1'b1,
                    "LOAD: WB_LOAD e escrita de registrador");
        tick;
    end
  	//---------------------------------------------------------------

  	//---------------------------------------------------------------
    // Stores: funct3 000,001,010.
  	// Checa se as instruções de STORE estão sendo reconhecidas.
    for (k=0; k<3; k=k+1) begin
        case (k)
          0: begin_instruction({7'b0000000,5'd2,5'd1,3'b000,5'd4,7'b0100011});
          1: begin_instruction({7'b0000000,5'd2,5'd1,3'b001,5'd4,7'b0100011});
          2: begin_instruction({7'b0000000,5'd2,5'd1,3'b010,5'd4,7'b0100011});
        endcase
        check(o_State == EX_ADDR && o_OP_Size == i_Instruction[14:12],
              "STORE: estado EX_ADDR e tamanho");
        tick; check(o_State == MEM_WRITE && o_Mem_Write && o_Addr_Sel,
                    "STORE: escrita de memoria");
        tick; check(o_State == FETCH, "STORE retorna a FETCH");
    end
  	//---------------------------------------------------------------
	
  	//---------------------------------------------------------------
    // Todas as 8 codificacoes de funct3 de BRANCH, com taken=0 e 
    // taken=1.
    // A condicao e fornecida pelo comparador externo.
  	// Checa se as instruções de desvio estão sendo reconhecidas.
    for (k=0; k<8; k=k+1) begin
        begin_instruction({7'b0000000,5'd2,5'd1,k[2:0],5'b00000,7'b1100011});
        i_Branch_Taken = 1'b0;
        #1;
        check(o_State == BRANCH && ai45.w_1 && ai45.w_2 == 2'b00,
              "BRANCH not-taken seleciona PC+4");
        tick; check(o_State == FETCH, "BRANCH not-taken retorna a FETCH");

        begin_instruction({7'b0000000,5'd2,5'd1,k[2:0],5'b00000,7'b1100011});
        i_Branch_Taken = 1'b1;
        #1;
        check(o_State == BRANCH && ai45.w_1 && ai45.w_2 == 2'b01,
              "BRANCH taken seleciona alvo");
        tick; check(o_State == FETCH, "BRANCH taken retorna a FETCH");
        i_Branch_Taken = 1'b0;
    end
 	//---------------------------------------------------------------

  	//---------------------------------------------------------------
    // JAL e JALR: execução e write-back do link.
    begin_instruction({20'h00001,5'd3,7'b1101111});
    check(o_State == JUMP && o_ALU_A_Sel == 2'b01,
          "JAL usa PC como operando A");
    tick; check(o_State == WB_LINK && o_Reg_Write &&
                o_Result_Sel == 3'd4, "JAL grava PC+4");
    check(ai45.w_1 && ai45.w_2 == 2'b01,
          "JAL seleciona o alvo do PC");
    tick;

    begin_instruction({12'd4,5'd1,3'b000,5'd3,7'b1100111});
    check(o_State == JUMP && o_ALU_A_Sel == 2'b00,
          "JALR usa rs1 como operando A");
    tick; check(o_State == WB_LINK && o_Reg_Write &&
                o_Result_Sel == 3'd4, "JALR grava PC+4");
    check(ai45.w_1 && ai45.w_2 == 2'b10,
          "JALR seleciona alvo com alinhamento");
    tick;
  	//---------------------------------------------------------------

  	//---------------------------------------------------------------
    // FENCE e opcode desconhecido: caminho SYSTEM como no-op.
    begin_instruction(32'h0000000f);
    check(o_State == SYSTEM && !o_Halt, "FENCE entra em SYSTEM");
    check(ai45.w_1, "FENCE avanca o PC");
    tick; check(o_State == FETCH, "FENCE retorna a FETCH");

    begin_instruction(32'h0000007f);
    check(o_State == SYSTEM && !o_Halt, "Opcode ilegal entra em SYSTEM");
    check(ai45.w_1, "Opcode ilegal avanca o PC");
    tick; check(o_State == FETCH, "Opcode ilegal retorna a FETCH");

    // ECALL: SYSTEM -> HALT, PC não avança e HALT permanece.
    begin_instruction(32'h00000073);
    check(o_State == SYSTEM && !o_Halt, "ECALL entra em SYSTEM");
    check(!ai45.w_1, "ECALL congela PC em SYSTEM");
    tick; check(o_State == HALT && o_Halt, "ECALL entra em HALT");
    tick; check(o_State == HALT && o_Halt, "HALT permanece parado");

    // EBREAK tambem deve parar, conforme a politica implementada.
    reset_dut;
    begin_instruction(32'h00100073);
    check(o_State == SYSTEM && !o_Halt, "EBREAK entra em SYSTEM");
    check(!ai45.w_1, "EBREAK congela PC em SYSTEM");
    tick; check(o_State == HALT && o_Halt, "EBREAK entra em HALT");

    // Outros funct3 de SYSTEM nao sao ECALL/EBREAK: no-op que avanca.
    reset_dut;
    begin_instruction(32'h00001073);
    check(o_State == SYSTEM && !o_Halt, "SYSTEM nao reconhecido entra em SYSTEM");
    check(ai45.w_1, "SYSTEM nao reconhecido avanca o PC");
    tick; check(o_State == FETCH, "SYSTEM nao reconhecido retorna a FETCH");
	//---------------------------------------------------------------
  
  	//---------------------------------------------------------------
    // Reset deve retirar a FSM de HALT.
    reset_dut;
    check(o_State == FETCH && !o_Halt, "Reset sai de HALT");
	//---------------------------------------------------------------
  
  	//---------------------------------------------------------------
    // Verificação do PC: incremento, retenção, alvo e 
  	// alinhamento JALR.
    // Após reset, PC=0x00400000.
    check(o_PC == 32'h00400000, "PC restaurado apos reset");
    check(o_PC_Plus4 == 32'h00400004, "PC+4 restaurado apos reset");
	//---------------------------------------------------------------
  	
  	//---------------------------------------------------------------
    // Controle integrado: uma instrução ALU termina e 
  	// incrementa PC em 4.
    i_Instruction = 32'h002081b3; // ADD x3,x1,x2
    tick; // FETCH -> DECODE
    tick; // DECODE -> EX_ALU
    tick; // EX_ALU -> WB_ALU
    tick; // WB_ALU escreve PC+4
    check(o_PC == 32'h00400004, "PC incrementa em 4 no write-back ALU");

  	//---------------------------------------------------------------
    // Testes randômicos de opcode/funct3 para procurar estados indefinidos.
    // São testes de robustez, não substituem a cobertura ISA formal.
    for (k=0; k<100; k=k+1) begin
        begin_instruction({$random,$random});
        check((^o_State !== 1'bx), "Robustez: estado sem X");
        check((^o_ALU_Op !== 1'bx), "Robustez: ALU_Op sem X");
        check((^o_Result_Sel !== 1'bx), "Robustez: Result_Sel sem X");
    end

    $display("");
    $display("==============================================");
    $display("RESUMO DOS TESTES");
    $display("Verificacoes executadas : %0d", tests);
    $display("Aprovadas               : %0d", passed);
    $display("Reprovadas              : %0d", failed);
    if (tests != 0)
        $display("Porcentagem de acerto   : %0.2f%%", (100.0*passed)/tests);
    else
        $display("Porcentagem de acerto   : N/A");
    $display("==============================================");
    $finish;
end

initial begin
    #200000;
    $display("ERRO: timeout da simulacao");
    $finish;
end

endmodule
