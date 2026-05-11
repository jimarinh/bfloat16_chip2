module rounder(
    input [10:0] mant_i,
    input [7:0] exp_i,
    output [7:0] mant_o,
    output [7:0] exp_o

    );

wire [8:0] mant_adder_output;
wire [7:0] mant_shift_output;
reg [8:0] mant_rounded;

wire [7:0] exp_adder_output;

//Discard grs bits
assign mant_shift_output={1'b0,mant_i[10:3]};

// Round adder
assign mant_adder_output ={1'b0,mant_i[10:3]}+9'd1;

      

// Multiplexer to select rounded output
always @(*) begin

case(mant_i[2:0])
3'b000:
 mant_rounded= mant_shift_output;
3'b001:
 mant_rounded= mant_shift_output;
3'b010:
 mant_rounded= mant_shift_output;
3'b011:
 mant_rounded= mant_shift_output;
3'b011:
 mant_rounded= mant_shift_output;
 3'b100:
 if(mant_i[3]==1'b1) 
 mant_rounded= mant_adder_output;
 else
 mant_rounded= mant_shift_output;
 
 default:
  mant_rounded= mant_adder_output;
endcase
end

// Exponent adder
assign exp_adder_output =exp_i+8'd1;  


// Multiplexer to check mantissa overflow
assign mant_o = (mant_rounded[8]==1'b1)?mant_rounded[8:1]:mant_rounded[7:0];
assign exp_o = (mant_rounded[8]==1'b1)?exp_adder_output:exp_i;
    
endmodule
