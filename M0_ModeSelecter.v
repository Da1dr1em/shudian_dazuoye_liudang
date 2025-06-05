`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2021/10/30 13:57:42
// Design Name: 
// Module Name: M0_ModeSelecter
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module M0_ModeSelecter(
    input            ENABLE,
    input            IN_CLK, // Clock input (from pin)
    input      [15:0]IN_SWITCH,
    input      [4:0] IN_BTN,
    output     [6:0] OUT_SEG0DATA,
    output     [6:0] OUT_SEG1DATA,
    output     [3:0] OUT_SEG0SELE,
    output     [3:0] OUT_SEG1SELE,
    output           OUT_SEG0DP,
    output           OUT_SEG1DP,
    output     [15:0]OUT_LED,
    input      [2:0] data
);
    reg [48:0] unshow = 48'b111111111111111111111111111111111111111111111111;//unshow<===>每一位熄�?(63<==>全不�?)
    reg [47:0] num = 48'b111111111111111111111111111111111111111111111111;//默认为不�?
    reg [47:0] numstar = 48'b111111111111111111111111111111111111111111111111;
    reg [7:0]  dp = 8'b0;
    reg [7:0]  dpstar = 8'b0;
    reg [7:0]  star = 8'b0;
    always @* begin
      //32 16 8 4 2 1
        case(data)
          0:begin
            star = 8'b11111111;//全位闪烁
            dpstar = 8'b0;
            //mode
            numstar = 48'b111111111111111111010110101010000000001101001110;
            //select
            num = 48'b011100001110010101001110001100011101111111111111;
            dp = 8'b00000000;
          end
          1:begin
            star = 8'b0;
            dpstar = 8'b0;
            numstar = unshow;
            num[47:45] = 3'b0; 
            num[44:42] = data[2:0];
            num[41:0] = 42'b001101_010010_011100_011001_010101_001010_100010;
            //翻译_�?7�?-> D_I_S_P_L_A_Y
            dp = 8'b10000000;
          end
          2:begin
            star = 8'b0;
            dpstar = 8'b0;
            numstar = unshow;
            num[47:45] = 3'b0; 
            num[44:42] = data[2:0];
            num[41:0] = 42'b001100_011000_011110_010111_011101_001110_011011;
            //翻译_�?7�?-> COUNTER
            dp = 8'b10000000;
          end
          3:begin
            star = 8'b0;
            dpstar = 8'b0;
            numstar = unshow;
            num[47:45] = 3'b0; 
            num[44:42] = data[2:0];
            num[41:0] = 42'b011101_010010_010110_101010_001110_011011_111111;
            //翻译_�?7�?-> T_I_M_ _E_R_ _
            dp = 8'b10000000;
          end
          4:begin
            star = 8'b0;
            dpstar = 8'b0;
            numstar = unshow;
            num[47:45] = 3'b0; 
            num[44:42] = data[2:0];
            num[41:0] = 42'b001101001110011101010010010110101010001110;
            dp = 8'b10000000;
          end
          5:begin
            star = 8'b0;
            dpstar = 8'b0;
            numstar = unshow;
            num[47:45] = 3'b0; 
            num[44:42] = data[2:0];
            
            num[41:0] = 42'b111111_010000_011110_001110_011100_011100_111111;
            dp = 8'b10000000;
          end
          default: begin
            star = 8'b0;
            dpstar = 8'b0;
            numstar = unshow;
            num[47:45] = 3'b0; 
            num[44:42] = data[2:0];
            num[41:0] = 42'b001110001110001110001110001110001110001110;
            dp = 8'b10000000;
          end  
        
        endcase
        //num[5:3] = 3'b0; 
        //num[2:0] = data[2:0];
        //num[47:45] = data[2:0];
    end
    seg7_starcontrol M0_seg7_0(
        .x          (num),
        .dp         (dp),
        .xstar      (numstar),
        .dpstar     (dpstar),
        .star       (star),
        .clk        (IN_CLK),
        .a_to_g1    (OUT_SEG0DATA),
        .an1        (OUT_SEG0SELE),
        .dp1        (OUT_SEG0DP),
        .a_to_g2    (OUT_SEG1DATA),
        .an2         (OUT_SEG1SELE),
        .dp2         (OUT_SEG1DP)
    );
endmodule
