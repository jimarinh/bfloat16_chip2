module sum_res_pp(
    input [7:0] mant_i,
    input [7:0] exp_diff_i,
    output [10:0] mant_o
    );

reg [10:0] i_mant_o;

      

// Multiplexer to select rounded output
always @(*) begin

case(exp_diff_i)
8'd0:
 i_mant_o={mant_i,3'b000};
8'd1:
 i_mant_o={1'b0,mant_i,2'b00};
8'd2:
 i_mant_o={2'b00,mant_i,1'b0};
8'd3:
 i_mant_o={3'b000,mant_i};
8'd4:
 i_mant_o={4'b0000,mant_i[7:1]};
8'd5:
 i_mant_o={5'b00000,mant_i[7:2]};
8'd6:
i_mant_o={6'b000000,mant_i[7:3]};
8'd7:
i_mant_o={7'b0000000,mant_i[7:4]};
8'd8: 
i_mant_o={8'b00000000,mant_i[7:5]};
 default:
  i_mant_o=11'd0;
endcase
end

assign mant_o = i_mant_o;
    
endmodule
