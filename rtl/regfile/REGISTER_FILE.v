module RISCV_REGISTER_FILE (

  input wire clk_i,
  input wire [4:0] rd_i,
  input wire [4:0] rs1_i,
  input wire [4:0] rs2_i,
  input wire we_i,
  input wire [31:0] wd_i,
  output wire [31:0] rs1_data_o,
  output wire [31:0] rs2_data_o

);

    // O registrador x0 é sempre zero, então não precisamos armazenar seu valor.
	reg [31:0] registers_r [1:31];
	
	always @(posedge clk_i) begin
		if(we_i && rd_i != 5'h0) begin // Evita escrever no registrador x0
			registers_r[rd_i] <= wd_i;
        end
	end
	
    // O registrador x0 é sempre zero, então se rs1 ou rs2 forem 0, 
    // retornamos 0 (a verificação evita comportamento indesejado).
	assign rs1_data_o = (rs1_i != 5'h0) ? registers_r[rs1_i] : 32'd0;
	assign rs2_data_o = (rs2_i != 5'h0) ? registers_r[rs2_i] : 32'd0;

endmodule