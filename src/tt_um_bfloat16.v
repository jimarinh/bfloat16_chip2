`default_nettype none

module tt_um_bfloat16 (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // will go high when the design is enabled
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);


bfloat16_chip mycore (
    .clk   (clk),
    .rst   (!rst_n),
    .MOSI  (ui_in[0]),
    .MISO  (uo_out[0]),
    .SCLK  (ui_in[1]),
    .SS    (ena ? ui_in[2] : 1'b1)
);

wire _unused = &{ui_in[7:3], uio_in, 1'b0};

assign uo_out[7:1] = 7'd0;
assign uio_out = 8'b0;
assign uio_oe = 8'b0;

endmodule