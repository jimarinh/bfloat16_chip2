
module leading_zero_norm(
    input [10:0] mantisa,
    input [7:0] exp,
    output reg [7:0] mantisa_r,
    output reg [7:0] exp_r
    );
    

wire [7:0] mant_o,exp_o;
    
// Round the result of subtraction    
rounder rounder0 (
    .mant_i(mantisa),
    .exp_i(exp),
    .mant_o(mant_o),
    .exp_o(exp_o)
    );
    
    
// Shift mantissa when operation is done
 always @(*)begin
     casex(mant_o)
     
     8'b1xxxxxxx: begin
     mantisa_r =mant_o;
     exp_r = exp_o;
     end
     8'b01xxxxxx:begin
     mantisa_r =mant_o<<1;
     exp_r = exp_o - 1; 
     end
     8'b001xxxxx:begin
     mantisa_r =mant_o<<2;
     exp_r = exp_o - 2; 
     end
     8'b0001xxxx:begin
     mantisa_r =mant_o<<3;
     exp_r = exp_o - 3; 
     end
     8'b00001xxx:begin
     mantisa_r =mant_o<<4;
     exp_r = exp_o - 4; 
     end
     8'b000001xx:begin
     mantisa_r =mant_o<<5;
     exp_r= exp_o- 5; 
     end
     8'b0000001x:begin
     mantisa_r =mant_o<<6;
     exp_r = exp_o - 6; 
     end
     8'b00000001:begin
     mantisa_r =mant_o<<7;
     exp_r = exp_o - 7; 
     end    
     default: begin
     mantisa_r = 0;
     exp_r = 0;                                
     end
     
   endcase
   end
endmodule
