`timescale 1ns/1ps

module testbench();

    // Sinais de Interface
    reg  [31:0] addr_i;
    reg  [2:0]  op_i;
    reg         oe_i;
    reg         we_i;
    reg  [31:0] mem_rdata_i;
    reg  [31:0] wdata_i;
    
    wire [31:0] rdata_o;
    wire [31:0] mem_wdata_o;
    wire [3:0]  bw_o;
    wire        op_fault_o;
    wire [31:0] addr_o;

    // Instanciação da DUT (Device Under Test)
    top dut (
        .addr_i(addr_i),
        .op_i(op_i),
        .oe_i(oe_i),
        .we_i(we_i),
        .mem_rdata_i(mem_rdata_i),
        .wdata_i(wdata_i),
        .rdata_o(rdata_o),
        .mem_wdata_o(mem_wdata_o),
        .bw_o(bw_o),
        .op_fault_o(op_fault_o),
        .addr_o(addr_o)
    );

    // Contadores de log
    integer errors = 0;
    integer tests  = 0;

    // --------------------------------------------------------
    // Tasks de Verificação Automática
    // --------------------------------------------------------

    // Task para testar operações de LOAD
    task check_load(
        input [31:0] t_addr,
        input [2:0]  t_op,
        input [31:0] t_mem_rdata,
        input [31:0] exp_rdata,
        input        exp_fault
    );
    begin
        addr_i      = t_addr;
        op_i        = t_op;
        oe_i        = 1'b1;
        we_i        = 1'b0;
        mem_rdata_i = t_mem_rdata;
        #1; 
        
        tests = tests + 1;
        if (op_fault_o !== exp_fault) begin
            $error("[FAIL] LOAD Falha de protocolo incorreta: Addr=%h, Op=%b | Exp Fault=%b, Got=%b", t_addr, t_op, exp_fault, op_fault_o);
            errors = errors + 1;
        end else if (!exp_fault && (rdata_o !== exp_rdata)) begin
            $error("[FAIL] LOAD Dado incorreto: Addr=%h, Op=%b | Exp Data=%h, Got=%h", t_addr, t_op, exp_rdata, rdata_o);
            errors = errors + 1;
        end
    end
    endtask

    // Task para testar operações de STORE
    task check_store(
        input [31:0] t_addr,
        input [2:0]  t_op,
        input [31:0] t_wdata,
        input [31:0] exp_mem_wdata,
        input [3:0]  exp_bw,
        input        exp_fault
    );
    begin
        addr_i  = t_addr;
        op_i    = t_op;
        oe_i    = 1'b0;
        we_i    = 1'b1;
        wdata_i = t_wdata;
        #1;
        
        tests = tests + 1;
        if (op_fault_o !== exp_fault) begin
            $error("[FAIL] STORE Falha de protocolo incorreta: Addr=%h, Op=%b | Exp Fault=%b, Got=%b", t_addr, t_op, exp_fault, op_fault_o);
            errors = errors + 1;
        end else if (!exp_fault && ((mem_wdata_o !== exp_mem_wdata) || (bw_o !== exp_bw))) begin
            $error("[FAIL] STORE Dado/Mascara incorreto: Addr=%h, Op=%b | Exp BW=%b/Data=%h, Got BW=%b/Data=%h", 
                   t_addr, t_op, exp_bw, exp_mem_wdata, bw_o, mem_wdata_o);
            errors = errors + 1;
        end
    end
    endtask

    // Task para testar violações simultâneas e Opcodes não mapeados
    task check_protocol(
        input [2:0] t_op,
        input       t_oe,
        input       t_we
    );
    begin
        addr_i = 32'h0000_0000;
        op_i   = t_op;
        oe_i   = t_oe;
        we_i   = t_we;
        #1;
        
        tests = tests + 1;
        if (op_fault_o !== 1'b1) begin
            $error("[FAIL] PROTOCOLO Falha não detectada: Op=%b, OE=%b, WE=%b", t_op, t_oe, t_we);
            errors = errors + 1;
        end
    end
    endtask

    // --------------------------------------------------------
    // Carga de Estímulos
    // --------------------------------------------------------
    initial begin
        $display("Iniciando bateria de testes na LSU...");

        // INICIALIZAÇÃO DE SINAIS
        addr_i = 0; op_i = 0; oe_i = 0; we_i = 0; mem_rdata_i = 0; wdata_i = 0;
        #5;

        // ==========================================
        // 1. TESTES DE LOAD COM SUCESSO E ALINHAMENTOS
        // Padrão lido da memória: 0x89ABCDEF (Teste de sinais negativos e extensões)
        // ==========================================
        
        // --- LB (000) Signed ---
        check_load(32'h0, 3'b000, 32'h89ABCDEF, 32'hFFFFFFEF, 0); // Byte 0 (EF -> ext negativo)
        check_load(32'h1, 3'b000, 32'h89ABCDEF, 32'hFFFFFFCD, 0); // Byte 1 (CD -> ext negativo)
        check_load(32'h2, 3'b000, 32'h89ABCDEF, 32'hFFFFFFAB, 0); // Byte 2 (AB -> ext negativo)
        check_load(32'h3, 3'b000, 32'h89ABCDEF, 32'hFFFFFF89, 0); // Byte 3 (89 -> ext negativo)

        // --- LBU (100) Unsigned ---
        check_load(32'h0, 3'b100, 32'h89ABCDEF, 32'h000000EF, 0); // Byte 0
        check_load(32'h2, 3'b100, 32'h89ABCDEF, 32'h000000AB, 0); // Byte 2

        // --- LH (001) Signed ---
        check_load(32'h0, 3'b001, 32'h89ABCDEF, 32'hFFFFCDEF, 0); // Halfword 0 (CDEF)
        check_load(32'h2, 3'b001, 32'h89ABCDEF, 32'hFFFF89AB, 0); // Halfword 1 (89AB)

        // --- LHU (101) Unsigned ---
        check_load(32'h0, 3'b101, 32'h89ABCDEF, 32'h0000CDEF, 0); // Halfword 0
        check_load(32'h2, 3'b101, 32'h89ABCDEF, 32'h000089AB, 0); // Halfword 1

        // --- LW (010) ---
        check_load(32'h0, 3'b010, 32'h89ABCDEF, 32'h89ABCDEF, 0); // Word (sem shift)

	// --- TESTES USANDO MSB POSITIVO (h76543210)
        
        // --- LB (000) Signed ---
        check_load(32'h0, 3'b000, 32'h76543210, 32'h00000010, 0); // Byte 0 (0x10 -> estende com 0)
        check_load(32'h1, 3'b000, 32'h76543210, 32'h00000032, 0); // Byte 1 (0x32 -> estende com 0)
        check_load(32'h2, 3'b000, 32'h76543210, 32'h00000054, 0); // Byte 2 (0x54 -> estende com 0)
        
        // --- LH (001) Signed ---
        check_load(32'h0, 3'b001, 32'h76543210, 32'h00003210, 0); // Halfword 0 (0x3210 -> estende com 0)
        check_load(32'h2, 3'b001, 32'h76543210, 32'h00007654, 0); // Halfword 1 (0x7654 -> estende com 0)


        // ==========================================
        // 2. TESTES DE STORE COM SUCESSO
        // Padrão a escrever: 0xAABBCCDD
        // ==========================================

        // --- SB (000) ---
        // Offset dita o shift nos dados de saída e a posição de BW
        check_store(32'h0, 3'b000, 32'hAABBCCDD, 32'hAABBCCDD, 4'b0001, 0); // Offset 0
      	check_store(32'h1, 3'b000, 32'hAABBCCDD, 32'hBBCCDD00, 4'b0010, 0); // Offset 1 (shift 8)
      	check_store(32'h2, 3'b000, 32'hAABBCCDD, 32'hCCDD0000, 4'b0100, 0); // Offset 2 (shift 16)
      	check_store(32'h3, 3'b000, 32'hAABBCCDD, 32'hDD000000, 4'b1000, 0); // Offset 3 (shift 24)

        // --- SH (001) ---
        check_store(32'h0, 3'b001, 32'hAABBCCDD, 32'hAABBCCDD, 4'b0011, 0); // Offset 0
      	check_store(32'h2, 3'b001, 32'hAABBCCDD, 32'hCCDD0000, 4'b1100, 0); // Offset 2

        // --- SW (010) ---
        check_store(32'h0, 3'b010, 32'hAABBCCDD, 32'hAABBCCDD, 4'b1111, 0); // Offset 0


        // ==========================================
        // 3. TESTES DE FAULTS DE ALINHAMENTO (MISALIGNED)
        // ==========================================
        
        // Load Halfword em offsets ímpares (1 e 3)
        check_load(32'h1, 3'b001, 32'h0, 32'h0, 1);
        check_load(32'h3, 3'b101, 32'h0, 32'h0, 1);
        
        // Store Halfword em offsets ímpares
        check_store(32'h1, 3'b001, 32'h0, 32'h0, 4'b0, 1);

        // Load Word em offsets não múltiplos de 4 (1, 2, 3)
        check_load(32'h1, 3'b010, 32'h0, 32'h0, 1);
        check_load(32'h2, 3'b010, 32'h0, 32'h0, 1);
        check_load(32'h3, 3'b010, 32'h0, 32'h0, 1);

        // Store Word em offsets não múltiplos de 4
        check_store(32'h1, 3'b010, 32'h0, 32'h0, 4'b0, 1);


        // ==========================================
        // 4. TESTES DE FAULTS DE PROTOCOLO E OPCODES
        // ==========================================
        
        // OE e WE simultâneos (violação arquitetural)
        check_protocol(3'b000, 1'b1, 1'b1);
        
        // Load usando opcode inexistente
        check_protocol(3'b011, 1'b1, 1'b0); // Opcode 3
        check_protocol(3'b110, 1'b1, 1'b0); // Opcode 6
        check_protocol(3'b111, 1'b1, 1'b0); // Opcode 7

        // Store usando opcodes de load unsigned ou inexistentes
        check_protocol(3'b011, 1'b0, 1'b1); // Opcode 3
        check_protocol(3'b100, 1'b0, 1'b1); // Store Byte Unsigned (inválido)
        check_protocol(3'b101, 1'b0, 1'b1); // Store Halfword Unsigned (inválido)

	// ==========================================
        // 6. TESTE DE IMUNIDADE A ENDEREÇOS MMIO (ZONA DMEM)
        // Endereço Base: 0x10010000
        // ==========================================
        
        // Acesso válido no offset 2 (0x10010002) - LSBs = 2'b10
        check_load(32'h10010002,  3'b000, 32'h89ABCDEF, 32'hFFFFFFAB, 0); // LB
        check_store(32'h10010002, 3'b001, 32'hAABBCCDD, 32'hCCDD0000, 4'b1100, 0); // SH

        // Falhas de alinhamento com endereço alto
        check_load(32'h10010001,  3'b010, 32'h0, 32'h0, 1); // LW em offset 1 (ímpar)
        check_store(32'h10010003, 3'b001, 32'h0, 32'h0, 4'b0, 1); // SH em offset 3

	// ==========================================
        // 7. CORNER CASES (ALL-ZEROS E ALL-ONES)
        // ==========================================
        
        // --- All-Zeros ---
        check_store(32'h0, 3'b010, 32'h00000000, 32'h00000000, 4'b1111, 0); // SW All-Zeros
        check_store(32'h2, 3'b001, 32'h00000000, 32'h00000000, 4'b1100, 0); // SH All-Zeros offset 2
        
        // --- All-Ones ---
        check_store(32'h0, 3'b010, 32'hFFFFFFFF, 32'hFFFFFFFF, 4'b1111, 0); // SW All-Ones
        
        // SB offset 1: All-ones sofrem shift left de 8 bits. Base direita deve ser preenchida com 00.
        check_store(32'h1, 3'b000, 32'hFFFFFFFF, 32'hFFFFFF00, 4'b0010, 0); 
        
        // SH offset 2: All-ones sofrem shift left de 16 bits. Base direita deve ser preenchida com 0000.
        check_store(32'h2, 3'b001, 32'hFFFFFFFF, 32'hFFFF0000, 4'b1100, 0); 

        // LBU All-Ones: Testa se a Zero-Extension blinda os 24 bits superiores contra saturação passiva
        check_load(32'h3, 3'b100, 32'hFFFFFFFF, 32'h000000FF, 0); // LBU Byte 3 (Extensão deve forçar MSBs a 0)

	

        // ==========================================
        // CONCLUSÃO E RESULTADOS
        // ==========================================
        #5;
        if (errors == 0) begin
            $display("\n=========================================");
            $display("SUCESSO: %0d testes executados sem erros.", tests);
            $display("=========================================\n");
        end else begin
            $display("\n=========================================");
            $display("FALHA: Encontrados %0d erros em %0d testes.", errors, tests);
            $display("=========================================\n");
        end
        $finish;
    end

endmodule