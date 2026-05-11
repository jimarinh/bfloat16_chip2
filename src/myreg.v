// Parameterizable register with enable and asynchronous reset
module myreg #(  parameter N = 16 )(
    input [N-1:0] d,
    output reg [N-1:0] q,
    input clk,
    input en,
    input rst
    );
   

      
   always @(posedge clk,posedge rst) begin
       if(rst==1)
            q<=0;
       else    
        if(en)
            q<=d;
   end
    
endmodule
