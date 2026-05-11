module exp_mant_logic(
    input [15:0] a,b,
    output [7:0] as_exp,
    output [10:0] mantisa_a,mantisa_b
    );
    
wire sel;
wire [7:0]exp_diff;
wire a_is_not_zero;
wire b_is_not_zero;
wire [10:0] mantisa_a_pp,mantisa_b_pp;

assign a_is_not_zero=(a[14:0]!=0)?1:0;
assign b_is_not_zero=(b[14:0]!=0)?1:0;

assign sel=a[14:7]>b[14:7]?1'b1:1'b0;
    
assign exp_diff = sel?a[14:7]-b[14:7]:b[14:7]-a[14:7];

assign as_exp = sel?a[14:7]:b[14:7];

sum_res_pp   pp0 (
    .mant_i({a_is_not_zero,a[6:0]}),
    .exp_diff_i(exp_diff),
    .mant_o(mantisa_a_pp)
);

sum_res_pp   pp1 (
    .mant_i({b_is_not_zero,b[6:0]}),
    .exp_diff_i(exp_diff),
    .mant_o(mantisa_b_pp)
);


 //normalize the lowest mantissa
assign mantisa_a=sel?{a_is_not_zero,a[6:0],3'b000}:mantisa_a_pp;
assign mantisa_b =sel?mantisa_b_pp:{b_is_not_zero,b[6:0],3'b000}; 
endmodule
