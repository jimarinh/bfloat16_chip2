// bfloat16 floating point multiplier
module fpmul(
    input [15:0] x1,
    input [15:0] x2,
    output [15:0] y,
    input clk,
    input rst,
    input en,
    output ready
    );

// Internal wires/signals declaration    
wire p_s;
wire [7:0] p_exp;
wire [7:0] exp_grs;
wire [7:0] p_mant;
wire [10:0] mant_grs;
wire [7:0] adder_out,sub_out;
wire [15:0] mult_out;
wire [15:0] result;
wire end1;


// Sign of result
assign p_s=x1[15] ^ x2[15];

// Adder of exponents
assign adder_out=x1[14:7]+x2[14:7];

// Multiplier of mantissas
assign mult_out=$unsigned({1'b1,x1[6:0]})*$unsigned({1'b1,x2[6:0]});

// Bias subtractor
assign sub_out=adder_out-8'd127;

// Exponent normalizer according to mantissa product
assign exp_grs= (mult_out[15]==1)?sub_out+8'd1 : sub_out;   

// Mantissa normalizer
assign mant_grs=(mult_out[15]==1)?mult_out[15:5] : mult_out[14:4];

// Product rounder using GRS bits    
rounder rounder0 (
    .mant_i(mant_grs),
    .exp_i(exp_grs),
    .mant_o(p_mant),
    .exp_o(p_exp)
    );

// Assign result  
assign result = (x1==0) ? {p_s,15'd0}: // x1 is zero -> result is zero
                (x2==0) ? {p_s,15'd0} : // x2 is zero -> result is zero  
                {p_s,p_exp,p_mant[6:0]};  // No special case, default result.


// Registers for enable
myreg #(.N(1)) reg1en(
.d(en),
 .q(end1),
 .clk(clk),
 .en(1'b1),
 .rst(rst)
);

// Connect register output to module output
assign y=result;
assign ready=end1;

endmodule
