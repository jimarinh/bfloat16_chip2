// bfloat16 floating point adder/substractor

module fp16sum_res(
    input [15:0] x1,
    input [15:0] x2,
    input clk,
    input rst,
    input add_sub,
    input en,
    output ready,
    output [15:0] y
    );
   
wire [7:0] as_exp,exp_r,exp_r1,exp_r2;
wire [10:0] mant_x1,mant_x2;
wire [7:0] mantisa_r1,mantisa_r2,mantisa_r;
wire [11:0] mantisa_r0;
wire sign_r,op_r;
wire end1;


// Exponent computation and input significand preprocessing
exp_mant_logic exp_mant_logic0(
    .a(x1),
    .b(x2),
    .as_exp(as_exp),
    .mantisa_a(mant_x1),
    .mantisa_b(mant_x2)
);

// Computes result sign and result significand
op_sign_logic op_sign_logic0(
     .mantisa_a(mant_x1),
     .mantisa_b(mant_x2),
     .mantisa_r(mantisa_r0),
     .sign_r(sign_r),
     .op_r(op_r),
     .add_sub(add_sub),
     .s_a(x1[15]),
     .s_b(x2[15])      
    );
    
// Leading zero normalization for subtraction
 leading_zero_norm leading_zero_norm0(
    .mantisa(mantisa_r0[10:0]),
    .exp(as_exp),
    .mantisa_r(mantisa_r1),
    .exp_r(exp_r1)
    );
    
// Mantissa normalization for addition
add_renorm add_renorm0(       
       .mantisa(mantisa_r0),
       .exp(as_exp),
       .mantisa_r(mantisa_r2),
       .exp_r(exp_r2) 
    );
    
 assign mantisa_r=op_r?mantisa_r1:mantisa_r2;
 assign exp_r=op_r?exp_r1:exp_r2;

 assign y = (mantisa_r==0)?16'd0:{sign_r,exp_r,mantisa_r[6:0]};




// Registers for enable
myreg #(.N(1)) reg1en(
.d(en),
 .q(end1),
 .clk(clk),
 .en(1'b1),
 .rst(rst)
);

 assign ready=end1;   
    
    
 endmodule
