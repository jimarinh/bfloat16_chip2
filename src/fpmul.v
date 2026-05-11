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
wire start_mpy;
wire done_mpy;

// Sign of result
assign p_s=x1[15] ^ x2[15];

// Adder of exponents
assign adder_out=x1[14:7]+x2[14:7];

// Multiplier of mantissas
//assign mult_out=$unsigned({1'b1,x1[6:0]})*$unsigned({1'b1,x2[6:0]});

serial_multiplier_8x8 u_mpy8x8(
    .clk(clk),
    .reset(rst),
    .start(start_mpy),      // Pulso de un ciclo para iniciar
    .a($unsigned({1'b1,x1[6:0]})),
    .b($unsigned({1'b1,x2[6:0]})),
    .product(mult_out),
    .done(done_mpy)
);

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
myreg #(.N(1)) reg1start(
.d(en),
 .q(start_mpy),
 .clk(clk),
 .en(1'b1),
 .rst(rst)
);

myreg #(.N(1)) reg1ready(
.d(done_mpy),
 .q(end1),
 .clk(clk),
 .en(1'b1),
 .rst(rst)
);

// Connect register output to module output
assign y=result;
assign ready=end1;

endmodule


module serial_multiplier_8x8 (
    input             clk,
    input             reset,      // Reset asíncrono activo en alto
    input             start,      // Pulso de un ciclo para iniciar
    input      [7:0]  a,          // Multiplicando
    input      [7:0]  b,          // Multiplicador
    output reg [15:0] product,    // Resultado
    output reg        busy,       // =1 mientras la operación está en curso
    output reg        done        // Pulso de 1 ciclo al finalizar
);

    // Registros internos
    reg [7:0]  multiplicand;
    reg [7:0]  multiplier;
    reg [15:0] accumulator;
    reg [3:0]  count;             // Cuenta de 0 a 8

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            multiplicand <= 8'd0;
            multiplier   <= 8'd0;
            accumulator  <= 16'd0;
            product      <= 16'd0;
            count        <= 4'd0;
            busy         <= 1'b0;
            done         <= 1'b0;
        end
        else begin
            // done es un pulso de un ciclo
            done <= 1'b0;

            // Iniciar operación
            if (start && !busy) begin
                multiplicand <= a;
                multiplier   <= b;
                accumulator  <= 16'd0;
                count        <= 4'd0;
                busy         <= 1'b1;
            end

            // Operación en curso
            else if (busy) begin

                // Si el bit menos significativo del multiplicador es 1,
                // sumar el multiplicando al acumulador
                if (multiplier[0]) begin
                    accumulator <= accumulator + {8'd0, multiplicand};
                end

                // Desplazamientos para la siguiente iteración
                multiplicand <= multiplicand << 1;
                multiplier   <= multiplier >> 1;
                count        <= count + 1'b1;

                // Después de 8 iteraciones, finalizar
                if (count == 4'd7) begin
                    // Si multiplier[0] = 1, el acumulador se actualiza con
                    // nonblocking assignment al final del ciclo. Por eso
                    // calculamos explícitamente el valor final.
                    product <= accumulator +
                               (multiplier[0] ? {8'd0, multiplicand} : 16'd0);

                    busy <= 1'b0;
                    done <= 1'b1;
                end
            end
        end
    end

endmodule