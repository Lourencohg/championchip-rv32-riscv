

//  ---------- INLCUDED BLOCK: crc8  ---------- 
module crc8(
    input  wire [7:0]  data_i,   
    input  wire [15:0] seed_i,   
    output wire [15:0] crc_o     
);
    assign crc_o[0]  = data_i[0] ^ seed_i[8]  ^ seed_i[12];
    assign crc_o[1]  = data_i[1] ^ seed_i[9]  ^ seed_i[13];
    assign crc_o[2]  = data_i[2] ^ seed_i[10] ^ seed_i[14];
    assign crc_o[3]  = data_i[3] ^ seed_i[11] ^ seed_i[15];
    assign crc_o[4]  = data_i[4] ^ seed_i[12];
    assign crc_o[5]  = data_i[5] ^ seed_i[8]  ^ seed_i[12] ^ seed_i[13];
    assign crc_o[6]  = data_i[6] ^ seed_i[9]  ^ seed_i[13] ^ seed_i[14];
    assign crc_o[7]  = data_i[7] ^ seed_i[10] ^ seed_i[14] ^ seed_i[15];
    assign crc_o[8]  = seed_i[0] ^ seed_i[11] ^ seed_i[15];
    assign crc_o[9]  = seed_i[1] ^ seed_i[12];
    assign crc_o[10] = seed_i[2] ^ seed_i[13];
    assign crc_o[11] = seed_i[3] ^ seed_i[14];
    assign crc_o[12] = seed_i[4] ^ seed_i[8]  ^ seed_i[12] ^ seed_i[15];
    assign crc_o[13] = seed_i[5] ^ seed_i[9]  ^ seed_i[13];
    assign crc_o[14] = seed_i[6] ^ seed_i[10] ^ seed_i[14];
    assign crc_o[15] = seed_i[7] ^ seed_i[11] ^ seed_i[15];
 
endmodule



//  ---------- INLCUDED BLOCK: crc16  ---------- 
module crc16 (
    input  wire [15:0] data_i,   
    input  wire [15:0] seed_i,   
    output wire [15:0] crc_o     
);
    assign crc_o[0]  = data_i[0]  ^ seed_i[0] ^ seed_i[4] ^ seed_i[8]  ^ seed_i[11] ^ seed_i[12];
    assign crc_o[1]  = data_i[1]  ^ seed_i[1] ^ seed_i[5] ^ seed_i[9]  ^ seed_i[12] ^ seed_i[13];
    assign crc_o[2]  = data_i[2]  ^ seed_i[2] ^ seed_i[6] ^ seed_i[10] ^ seed_i[13] ^ seed_i[14];
    assign crc_o[3]  = data_i[3]  ^ seed_i[3] ^ seed_i[7] ^ seed_i[11] ^ seed_i[14] ^ seed_i[15];
    assign crc_o[4]  = data_i[4]  ^ seed_i[4] ^ seed_i[8] ^ seed_i[12] ^ seed_i[15];
    assign crc_o[5]  = data_i[5]  ^ seed_i[0] ^ seed_i[4] ^ seed_i[5]  ^ seed_i[8]  ^ seed_i[9]  ^ seed_i[11] ^ seed_i[12] ^ seed_i[13];
    assign crc_o[6]  = data_i[6]  ^ seed_i[1] ^ seed_i[5] ^ seed_i[6]  ^ seed_i[9]  ^ seed_i[10] ^ seed_i[12] ^ seed_i[13] ^ seed_i[14];
    assign crc_o[7]  = data_i[7]  ^ seed_i[2] ^ seed_i[6] ^ seed_i[7]  ^ seed_i[10] ^ seed_i[11] ^ seed_i[13] ^ seed_i[14] ^ seed_i[15];
    assign crc_o[8]  = data_i[8]  ^ seed_i[3] ^ seed_i[7] ^ seed_i[8]  ^ seed_i[11] ^ seed_i[12] ^ seed_i[14] ^ seed_i[15];
    assign crc_o[9]  = data_i[9]  ^ seed_i[4] ^ seed_i[8] ^ seed_i[9]  ^ seed_i[12] ^ seed_i[13] ^ seed_i[15];
    assign crc_o[10] = data_i[10] ^ seed_i[5] ^ seed_i[9] ^ seed_i[10] ^ seed_i[13] ^ seed_i[14];
    assign crc_o[11] = data_i[11] ^ seed_i[6] ^ seed_i[10] ^ seed_i[11] ^ seed_i[14] ^ seed_i[15];
    assign crc_o[12] = data_i[12] ^ seed_i[0] ^ seed_i[4] ^ seed_i[7]  ^ seed_i[8]  ^ seed_i[15];
    assign crc_o[13] = data_i[13] ^ seed_i[1] ^ seed_i[5] ^ seed_i[8]  ^ seed_i[9];
    assign crc_o[14] = data_i[14] ^ seed_i[2] ^ seed_i[6] ^ seed_i[9]  ^ seed_i[10];
    assign crc_o[15] = data_i[15] ^ seed_i[3] ^ seed_i[7] ^ seed_i[10] ^ seed_i[11];
 
endmodule



//  ---------- INLCUDED BLOCK: crc32  ---------- 
module crc32 (
    input  wire [31:0] data_i,   
    input  wire [15:0] seed_i,   
    output wire [15:0] crc_o    
);
    assign crc_o[0]  = data_i[0]  ^ data_i[16] ^ data_i[20] ^ data_i[24] ^ data_i[27] ^ data_i[28]
                      ^ seed_i[3] ^ seed_i[4]  ^ seed_i[6]  ^ seed_i[10] ^ seed_i[11] ^ seed_i[12];
 
    assign crc_o[1]  = data_i[1]  ^ data_i[17] ^ data_i[21] ^ data_i[25] ^ data_i[28] ^ data_i[29]
                      ^ seed_i[4] ^ seed_i[5]  ^ seed_i[7]  ^ seed_i[11] ^ seed_i[12] ^ seed_i[13];
 
    assign crc_o[2]  = data_i[2]  ^ data_i[18] ^ data_i[22] ^ data_i[26] ^ data_i[29] ^ data_i[30]
                      ^ seed_i[5] ^ seed_i[6]  ^ seed_i[8]  ^ seed_i[12] ^ seed_i[13] ^ seed_i[14];
 
    assign crc_o[3]  = data_i[3]  ^ data_i[19] ^ data_i[23] ^ data_i[27] ^ data_i[30] ^ data_i[31]
                      ^ seed_i[6] ^ seed_i[7]  ^ seed_i[9]  ^ seed_i[13] ^ seed_i[14] ^ seed_i[15];
 
    assign crc_o[4]  = data_i[4]  ^ data_i[20] ^ data_i[24] ^ data_i[28] ^ data_i[31] ^ seed_i[0] 
                       ^ seed_i[7]  ^ seed_i[8]  ^ seed_i[10] ^ seed_i[14] ^ seed_i[15];
 
    assign crc_o[5]  = data_i[5]  ^ data_i[16] ^ data_i[20] ^ data_i[21] ^ data_i[24] ^ data_i[25] 
                       ^ data_i[27] ^ data_i[28] ^ data_i[29] ^ seed_i[0] ^ seed_i[1]  ^ seed_i[3]  
                       ^ seed_i[4]  ^ seed_i[6]  ^ seed_i[8]  ^ seed_i[9]  ^ seed_i[10] ^ seed_i[12] ^ seed_i[15];
 
    assign crc_o[6]  = data_i[6]  ^ data_i[17] ^ data_i[21] ^ data_i[22] ^ data_i[25] ^ data_i[26] 
                       ^ data_i[28] ^ data_i[29] ^ data_i[30] ^ seed_i[1] ^ seed_i[2]  ^ seed_i[4]  
                       ^ seed_i[5]  ^ seed_i[7]  ^ seed_i[9]  ^ seed_i[10] ^ seed_i[11] ^ seed_i[13];
 
    assign crc_o[7]  = data_i[7]  ^ data_i[18] ^ data_i[22] ^ data_i[23] ^ data_i[26] ^ data_i[27] 
                       ^ data_i[29] ^ data_i[30] ^ data_i[31] ^ seed_i[2] ^ seed_i[3]  ^ seed_i[5]
                       ^ seed_i[6]  ^ seed_i[8]  ^ seed_i[10] ^ seed_i[11] ^ seed_i[12] ^ seed_i[14];
 
    assign crc_o[8]  = data_i[8]  ^ data_i[19] ^ data_i[23] ^ data_i[24] ^ data_i[27] ^ data_i[28] 
                       ^ data_i[30] ^ data_i[31] ^ seed_i[0] ^ seed_i[3]  ^ seed_i[4]  ^ seed_i[6]  
                       ^ seed_i[7]  ^ seed_i[9]  ^ seed_i[11] ^ seed_i[12] ^ seed_i[13] ^ seed_i[15];
 
    assign crc_o[9]  = data_i[9]  ^ data_i[20] ^ data_i[24] ^ data_i[25] ^ data_i[28] ^ data_i[29] 
                       ^ data_i[31]^ seed_i[0] ^ seed_i[1]  ^ seed_i[4]  ^ seed_i[5]  ^ seed_i[7]  
                       ^ seed_i[8]  ^ seed_i[10] ^ seed_i[12] ^ seed_i[13] ^ seed_i[14];
 
    assign crc_o[10] = data_i[10] ^ data_i[21] ^ data_i[25] ^ data_i[26] ^ data_i[29] ^ data_i[30]
                      ^ seed_i[0] ^ seed_i[1]  ^ seed_i[2]  ^ seed_i[5]  ^ seed_i[6]  ^ seed_i[8]  
                      ^ seed_i[9]  ^ seed_i[11] ^ seed_i[13] ^ seed_i[14] ^ seed_i[15];
 
    assign crc_o[11] = data_i[11] ^ data_i[22] ^ data_i[26] ^ data_i[27] ^ data_i[30] ^ data_i[31]
                      ^ seed_i[1] ^ seed_i[2]  ^ seed_i[3]  ^ seed_i[6]  ^ seed_i[7]  ^ seed_i[9]  
                      ^ seed_i[10] ^ seed_i[12] ^ seed_i[14] ^ seed_i[15];
 
    assign crc_o[12] = data_i[12] ^ data_i[16] ^ data_i[20] ^ data_i[23] ^ data_i[24] ^ data_i[31]
                      ^ seed_i[0] ^ seed_i[2]  ^ seed_i[6]  ^ seed_i[7]  ^ seed_i[8]  ^ seed_i[12]
                      ^ seed_i[13] ^ seed_i[15];
 
    assign crc_o[13] = data_i[13] ^ data_i[17] ^ data_i[21] ^ data_i[24] ^ data_i[25]
                      ^ seed_i[0] ^ seed_i[1]  ^ seed_i[3]  ^ seed_i[7]  ^ seed_i[8]  ^ seed_i[9]  
                      ^ seed_i[13] ^ seed_i[14];
 
    assign crc_o[14] = data_i[14] ^ data_i[18] ^ data_i[22] ^ data_i[25] ^ data_i[26]
                      ^ seed_i[1] ^ seed_i[2]  ^ seed_i[4]  ^ seed_i[8]  ^ seed_i[9]  ^ seed_i[10] 
                      ^ seed_i[14] ^ seed_i[15];
 
    assign crc_o[15] = data_i[15] ^ data_i[19] ^ data_i[23] ^ data_i[26] ^ data_i[27]
                      ^ seed_i[2] ^ seed_i[3]  ^ seed_i[5]  ^ seed_i[9]  ^ seed_i[10] ^ seed_i[11] 
                      ^ seed_i[15];
 
endmodule



//  ---------- INLCUDED BLOCK: mux3x1_16bits  ---------- 
module mux3x1_16bits (
    input  wire [3:0]  crc_sel_i,
    input  wire [15:0] crc8_i,
    input  wire [15:0] crc16_i,
    input  wire [15:0] crc32_i,
    output reg  [15:0] crc_sel_o
);
 
    always @(*) begin
        case (crc_sel_i)
            4'h0:    crc_sel_o = crc8_i;
            4'h1:    crc_sel_o = crc16_i;
            4'h2:    crc_sel_o = crc32_i;
            default: crc_sel_o = 16'h0000;
        endcase
    end
 
endmodule


// Automatically generated by ChipInventor Cloud EDA Tool - 3.15
// Careful: this file (hdl.v) will be automatically replaced
// when you ask tool to generate top Verilog code by clicking
// at BLOCKS button.

module top (

  input wire [31:0] crc_a_i,
  input wire [15:0] crc_b_i,
  input wire [3:0] crc_sel_i,
  output wire [15:0] crc_result_o

);

//Internal Wires
 wire [15:0] w_1;
 wire [15:0] w_2;
 wire [15:0] w_3;

//Instances of Modules
crc8 blk4486_5 (
         .data_i (crc_a_i[31:0]),
         .seed_i (crc_b_i[15:0]),
         .crc_o (w_1)
     );

crc32 blk4488_6 (
         .data_i (crc_a_i[31:0]),
         .seed_i (crc_b_i[15:0]),
         .crc_o (w_2)
     );

crc16 blk4487_7 (
         .data_i (crc_a_i[31:0]),
         .seed_i (crc_b_i[15:0]),
         .crc_o (w_3)
     );

mux3x1_16bits blk4489_8 (
         .crc_sel_i (crc_sel_i[3:0]),
         .crc_sel_o (crc_result_o[15:0]),
         .crc8_i (w_1),
         .crc32_i (w_2),
         .crc16_i (w_3)
     );


endmodule
