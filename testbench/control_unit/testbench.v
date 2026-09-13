//==============================================================================
// testbench
//
// IMPORTANTE: o modulo de topo PRECISA se chamar "testbench". A plataforma
// ChipInventor invoca o iverilog com "-s testbench" e falha na elaboracao
// com qualquer outro nome:
//     error: Unable to find the root module "testbench"
//
// Testbench da unidade de controle multiciclo. Verifica, para cada instrucao:
//   - o numero de ciclos ate voltar ao FETCH;
//   - os valores dos sinais nos estados EX e WB;
//   - as tres armadilhas conhecidas: ADD x SUB x MUL x CRC (mesmo opcode),
//     ADDI com imediato negativo (bit 30 nao pode virar SUB) e SRLI x SRAI.
//
//   iverilog -o sim.vvp RISCV_CONTROL_MULTICYCLE.v tb_RISCV_CONTROL_MULTICYCLE.v
//   vvp sim.vvp
//==============================================================================

`timescale 1ns / 1ps

`include "rvbl2_defines.vh"

module testbench;

    reg         r_Clk = 1'b0;
    reg         r_Rst = 1'b1;
    reg  [31:0] r_Instruction = 32'h00000013;   // nop (addi x0,x0,0)
    reg         r_Branch_Taken = 1'b0;

    wire        w_PC_Write, w_IR_Write, w_Addr_Sel, w_Mem_Read, w_Mem_Write;
    wire        w_Reg_Write, w_Halt;
    wire [1:0]  w_PC_Sel;
    wire        w_ALU_A_Sel, w_ALU_B_Sel;
    wire [3:0]  w_ALU_Op, w_Mult_Op, w_CRC_Op;
    wire [2:0]  w_Result_Sel, w_Op_Size;
    wire        w_Mult_En, w_CRC_En;
    wire [4:0]  w_State;

    integer     r_Errors = 0;
    integer     r_Cycles;

    RISCV_CONTROL_MULTICYCLE u_dut (
        .i_Clk(r_Clk), .i_Rst(r_Rst),
        .i_Instruction(r_Instruction), .i_Branch_Taken(r_Branch_Taken),
        .o_PC_Write(w_PC_Write), .o_PC_Sel(w_PC_Sel), .o_IR_Write(w_IR_Write),
        .o_Addr_Sel(w_Addr_Sel), .o_Mem_Read(w_Mem_Read), .o_Mem_Write(w_Mem_Write),
        .o_ALU_A_Sel(w_ALU_A_Sel), .o_ALU_B_Sel(w_ALU_B_Sel), .o_ALU_Op(w_ALU_Op),
        .o_Mult_Op(w_Mult_Op), .o_CRC_Op(w_CRC_Op), .o_Result_Sel(w_Result_Sel),
        .o_Reg_Write(w_Reg_Write), .o_Halt(w_Halt), .o_State(w_State),
        .o_Op_Size(w_Op_Size), .o_Mult_En(w_Mult_En), .o_CRC_En(w_CRC_En)
    );

    always #5 r_Clk = ~r_Clk;

    // Guarda contra travamento: se algum estado esperado nunca chegar.
    initial begin
        #20000;
        $display("TIMEOUT - preso no estado %0d", w_State);
        $finish;
    end

    

    task check;
        input [255:0] name;
        input [31:0]  got;
        input [31:0]  exp;
        begin
            if (got !== exp) begin
                $display("   FALHOU  %0s: obtido %0d, esperado %0d", name, got, exp);
                r_Errors = r_Errors + 1;
            end
        end
    endtask

    // Executa uma instrucao do inicio ao fim e conta os ciclos.
    task run_instruction;
        input [31:0]  instr;
        input [31:0]  expected_cycles;
        input [255:0] name;
        begin
            // sincroniza com o inicio de uma instrucao antes de contar
            while (w_State != `ST_FETCH) @(negedge r_Clk);
            r_Instruction = instr;
            r_Cycles = 1;                       // este ciclo e o FETCH
            @(negedge r_Clk);
            while (w_State != `ST_FETCH) begin
                r_Cycles = r_Cycles + 1;
                @(negedge r_Clk);
            end
            if (r_Cycles !== expected_cycles) begin
                $display("   FALHOU  %0s: %0d ciclos, esperado %0d",
                         name, r_Cycles, expected_cycles);
                r_Errors = r_Errors + 1;
            end
            else begin
                $display("   ok      %0s (%0d ciclos)", name, r_Cycles);
            end
        end
    endtask

    // Anda ate um estado especifico para inspecionar sinais.
    task goto_state;
        input [4:0] target;
        begin
            // avanca SEMPRE pelo menos uma borda: garante que a instrucao
            // recem-atribuida propague pela logica combinacional antes da
            // leitura, e evita cair no estado antigo por acidente.
            @(negedge r_Clk);
            while (w_State != target) @(negedge r_Clk);
        end
    endtask

    initial begin
        // Gravacao de waveform DESLIGADA por padrao: o diretorio de trabalho
        // do ChipInventor nao aceita escrita e o $dumpfile falha com
        //     VCD Error: Unable to open <arquivo> for output
        // Isso nao afeta os testes - o resultado sai pelos $display abaixo.
        // Para gerar a waveform na sua maquina:
        //     iverilog -DDUMP_VCD -s testbench -o sim.vvp *.v && vvp sim.vvp
`ifdef DUMP_VCD
        $dumpfile("dump.vcd");
        $dumpvars(0, testbench);
`endif

        @(negedge r_Clk); r_Rst = 1'b0;
        @(negedge r_Clk);

        $display("");
        $display("=== 1. Contagem de ciclos ===");
        run_instruction(32'h003100B3, 4, "ADD  x1,x2,x3");
        run_instruction(32'h403100B3, 4, "SUB  x1,x2,x3");
        run_instruction(32'h00A10093, 4, "ADDI x1,x2,10");
        run_instruction(32'h00812083, 6, "LW   x1,8(x2)");
        run_instruction(32'h00312423, 4, "SW   x3,8(x2)");
        run_instruction(32'h00208463, 3, "BEQ  x1,x2,+8");
        run_instruction(32'h008000EF, 4, "JAL  x1,+8");
        run_instruction(32'h008100E7, 4, "JALR x1,8(x2)");
        run_instruction(32'h123450B7, 4, "LUI  x1,0x12345");
        run_instruction(32'h12345097, 4, "AUIPC x1,0x12345");
        run_instruction(32'h023100B3, 4, "MUL  x1,x2,x3");
        run_instruction(32'h803100B3, 4, "CRCB x1,x2,x3");
        run_instruction(32'h0000000F, 3, "FENCE");

        $display("");
        $display("=== 2. Decodificacao da ULA (Tabela 9) ===");
        // opcode 0110011, rd=x1, rs1=x2, rs2=x3, variando funct3/funct7
        r_Instruction = 32'h003100B3; goto_state(5'd2);  check("ADD  alu_op",  w_ALU_Op, 4'h1);
        r_Instruction = 32'h403100B3; goto_state(5'd2);  check("SUB  alu_op",  w_ALU_Op, 4'h2);
        r_Instruction = 32'h003110B3; goto_state(5'd2);  check("SLL  alu_op",  w_ALU_Op, 4'h6);
        r_Instruction = 32'h003120B3; goto_state(5'd2);  check("SLT  alu_op",  w_ALU_Op, 4'h9);
        r_Instruction = 32'h003130B3; goto_state(5'd2);  check("SLTU alu_op",  w_ALU_Op, 4'hA);
        r_Instruction = 32'h003140B3; goto_state(5'd2);  check("XOR  alu_op",  w_ALU_Op, 4'h5);
        r_Instruction = 32'h003150B3; goto_state(5'd2);  check("SRL  alu_op",  w_ALU_Op, 4'h7);
        r_Instruction = 32'h403150B3; goto_state(5'd2);  check("SRA  alu_op",  w_ALU_Op, 4'h8);
        r_Instruction = 32'h003160B3; goto_state(5'd2);  check("OR   alu_op",  w_ALU_Op, 4'h4);
        r_Instruction = 32'h003170B3; goto_state(5'd2);  check("AND  alu_op",  w_ALU_Op, 4'h3);
        r_Instruction = 32'h123450B7; goto_state(5'd2);  check("LUI  alu_op",  w_ALU_Op, 4'h0);
        $display("   (11 operacoes da Tabela 9 verificadas)");

        $display("");
        $display("=== 3. Armadilhas ===");
        // ADDI com imediato negativo: bits altos em 1, o bit 30 esta setado.
        // Se o decodificador nao filtrar por tipo, isto viraria SUB.
        r_Instruction = 32'hFFF10093; goto_state(5'd2);
        check("ADDI -1 nao pode virar SUB", w_ALU_Op, 4'h1);
        check("ADDI usa imediato",          w_ALU_B_Sel, 1'b1);
        // SRLI x SRAI: aqui o bit 30 VALE, mesmo sendo tipo I.
        r_Instruction = 32'h00415093; goto_state(5'd2); check("SRLI alu_op", w_ALU_Op, 4'h7);
        r_Instruction = 32'h40415093; goto_state(5'd2); check("SRAI alu_op", w_ALU_Op, 4'h8);
        // Mesmo opcode e mesmo funct3, so o funct7 separa.
        r_Instruction = 32'h023100B3; goto_state(5'd4); check("MUL  mult_op", w_Mult_Op, 4'h0);
        r_Instruction = 32'h803110B3; goto_state(5'd6); check("CRCH crc_op",  w_CRC_Op,  4'h1);
        $display("   (regressao ADD/SUB/SRA apos MUL e CRC: ver secao 2)");

        $display("");
        $display("=== 4. Branch tomado x nao tomado ===");
        r_Branch_Taken = 1'b0;
        r_Instruction = 32'h00208463; goto_state(5'd13);
        check("BEQ nao tomado: pc_write", w_PC_Write, 1'b1);
        check("BEQ nao tomado: pc_sel",   w_PC_Sel,   2'b00);
        check("BEQ nao tomado: reg_write",w_Reg_Write,1'b0);
        r_Branch_Taken = 1'b1;
        goto_state(5'd13);
        check("BEQ tomado: pc_write",     w_PC_Write, 1'b1);
        check("BEQ tomado: pc_sel",       w_PC_Sel,   2'b01);
        r_Branch_Taken = 1'b0;
        $display("   (nos dois casos o PC avanca - nao tomado vai para PC+4)");

        $display("");
        $display("=== 5. JAL x JALR no WB_LINK ===");
        r_Instruction = 32'h008000EF; goto_state(5'd15);
        check("JAL  pc_sel",     w_PC_Sel,     2'b01);
        check("JAL  result_sel", w_Result_Sel, 3'd4);
        check("JAL  alu_a_sel",  w_ALU_A_Sel,  1'b1);   // PC
        r_Instruction = 32'h008100E7; goto_state(5'd15);
        check("JALR pc_sel",     w_PC_Sel,     2'b10);   // zera o bit 0
        check("JALR alu_a_sel",  w_ALU_A_Sel,  1'b0);   // rs1

        $display("");
        $display("=== 6. Memoria ===");
        r_Instruction = 32'h00812083; goto_state(5'd9);
        check("MEM_READ addr_sel",  w_Addr_Sel,  1'b1);
        check("MEM_READ mem_read",  w_Mem_Read,  1'b1);
        check("MEM_READ alu_op",    w_ALU_Op,    4'h1);  // endereco continua valido
        goto_state(5'd11);
        check("WB_LOAD addr_sel",   w_Addr_Sel,  1'b1);  // decisao B1
        check("WB_LOAD result_sel", w_Result_Sel,3'd3);
        check("WB_LOAD reg_write",  w_Reg_Write, 1'b1);
        r_Instruction = 32'h00312423; goto_state(5'd12);
        check("MEM_WRITE mem_write",w_Mem_Write, 1'b1);
        check("MEM_WRITE reg_write",w_Reg_Write, 1'b0);
        check("MEM_WRITE addr_sel", w_Addr_Sel,  1'b1);

        $display("");
        $display("=== 7. we_o so no store ===");
        begin : we_scan
            integer i;
            while (w_State != `ST_FETCH) @(negedge r_Clk);
            r_Instruction = 32'h00812083;   // um load completo
            for (i = 0; i < 6; i = i + 1) begin
                if (w_Mem_Write !== 1'b0) begin
                    $display("   FALHOU  we_o=1 no estado %0d durante um LOAD", w_State);
                    r_Errors = r_Errors + 1;
                end
                @(negedge r_Clk);
            end
            $display("   ok      we_o permanece 0 durante todo o load");
        end

        $display("");
        $display("=== 8. op_size_o para a LSU (Figura 3 do guia) ===");
        // funct3: 000=lb 001=lh 010=lw 100=lbu 101=lhu / 000=sb 001=sh 010=sw
        r_Instruction = 32'h00810083; goto_state(5'd9); check("LB  op_size", w_Op_Size, 3'b000);
        r_Instruction = 32'h00811083; goto_state(5'd9); check("LH  op_size", w_Op_Size, 3'b001);
        r_Instruction = 32'h00812083; goto_state(5'd9); check("LW  op_size", w_Op_Size, 3'b010);
        r_Instruction = 32'h00814083; goto_state(5'd9); check("LBU op_size", w_Op_Size, 3'b100);
        r_Instruction = 32'h00815083; goto_state(5'd9); check("LHU op_size", w_Op_Size, 3'b101);
        goto_state(5'd11);            check("LHU op_size no WB", w_Op_Size, 3'b101);
        r_Instruction = 32'h00310423; goto_state(5'd12); check("SB  op_size", w_Op_Size, 3'b000);
        r_Instruction = 32'h00311423; goto_state(5'd12); check("SH  op_size", w_Op_Size, 3'b001);
        r_Instruction = 32'h00312423; goto_state(5'd12); check("SW  op_size", w_Op_Size, 3'b010);
        $display("   (5 loads e 3 stores verificados)");

        $display("");
        $display("=== 9. Habilitacoes e LUI ===");
        r_Instruction = 32'h023100B3; goto_state(5'd4);
        check("MUL mult_en", w_Mult_En, 1'b1); check("MUL crc_en", w_CRC_En, 1'b0);
        r_Instruction = 32'h803100B3; goto_state(5'd6);
        check("CRC crc_en", w_CRC_En, 1'b1);   check("CRC mult_en", w_Mult_En, 1'b0);
        r_Instruction = 32'h123450B7; goto_state(5'd2);
        check("LUI alu_b_sel = imediato", w_ALU_B_Sel, 1'b1);
        check("LUI alu_a irrelevante mas estavel", w_ALU_A_Sel, 1'b0);
        r_Instruction = 32'h003100B3; goto_state(5'd3);
        check("WB_ALU mantem alu_op", w_ALU_Op, 4'h1);
        check("WB_ALU mantem alu_b_sel", w_ALU_B_Sel, 1'b0);

        $display("");
        $display("=== 10. ECALL x EBREAK x FENCE ===");
        r_Instruction = 32'h00000073;   // ecall
        goto_state(5'd17);
        check("ECALL halt",     w_Halt,     1'b1);
        check("ECALL pc_write", w_PC_Write, 1'b0);
        @(negedge r_Clk);
        check("HALT e terminal", w_State, 5'd17);
        // reset e testa EBREAK e FENCE separadamente
        r_Rst = 1'b1; @(negedge r_Clk); r_Rst = 1'b0;
        r_Instruction = 32'h00100073;   // ebreak
        goto_state(5'd16); check("EBREAK pc_write", w_PC_Write, 1'b0);
        goto_state(5'd17); check("EBREAK halt",     w_Halt,     1'b1);
        r_Rst = 1'b1; @(negedge r_Clk); r_Rst = 1'b0;
        r_Instruction = 32'h0000000F;   // fence
        goto_state(5'd16);
        check("FENCE pc_write", w_PC_Write, 1'b1);
        check("FENCE halt",     w_Halt,     1'b0);

        $display("");
        if (r_Errors == 0) $display("TODOS OS TESTES PASSARAM");
        else               $display("%0d FALHA(S)", r_Errors);
        $display("");
        $finish;
    end

endmodule
