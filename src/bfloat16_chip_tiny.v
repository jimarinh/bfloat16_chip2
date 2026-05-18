module bfloat16_chip(
    input  clk,
    input  rst,
    output MISO,
    input  MOSI,
    input  SCLK,
    input  SS
);

reg loadA;
reg loadB;
reg resetACC;
reg loadACC;
reg loadPISO;
wire [15:0] sipo_reg; 
wire [15:0] regA;
wire [15:0] regB;
wire [15:0] acc;
reg  en_addsub;
reg  en_mpy;
wire ready_sipo;
wire ready_addsub;
wire ready_mpy;
wire ready_op;

wire [15:0] out_addsub;
wire [15:0] out_mpy;

//SPI Interface
//----------------------------
spi_controller u_spi (
    .clk(clk),
    .reset(rst),
    .sclk(SCLK),
    .ss(SS),
    .mosi(MOSI),
    .miso(MISO),
    .load_tx(loadPISO),
    .data_tx(acc), //Always send the accumulator
    .data_rx(sipo_reg), //Received data
    .ready(ready_sipo) // Set when a word is complete 
);


assign ready_op = (ready_addsub & en_addsub) | (ready_mpy & en_mpy);

//Operands' registers
//----------------------------
register u_regA(
    .clk(clk),
    .rst(rst),
    .load(ready_sipo & loadA),
    .d(sipo_reg),
    .q(regA)
);

register u_regB(
    .clk(clk),
    .rst(rst),
    .load(ready_sipo & loadB),
    .d(sipo_reg),
    .q(regB)
);

//Accumulator 
//----------------------------
wire [15:0] acc_in;

assign acc_in = resetACC ? 16'h0000 : out_addsub;

register u_acc(
    .clk(clk),
    .rst(rst),
    .load(loadACC),
    .d(acc_in),
    .q(acc)
);

//Bfloat16 adder
//----------------------------
fp16sum_res u_addsub(
    .clk(clk),
    .rst(rst),
    .add_sub(1'b0),
    .en(en_addsub),
    .x1(acc),
    .x2( out_mpy),
    .y(out_addsub),
    .ready(ready_addsub)
);

//Bfloat16 multiplier
//----------------------------
fpmul u_mpy(
    .clk(clk),
    .rst(rst),
    .en(en_mpy),
    .x1(regA),
    .x2(regB),
    .y(out_mpy),
    .ready(ready_mpy)
);

//FSM for control path
//----------------------------

// Machine states
localparam Idle         = 3'd0; //Idle
localparam WaitNextData1= 3'd1; //Wait for SPI ready signal to be disabled
localparam WaitData1    = 3'd2; //Wait SPI reception of first operand
localparam WaitComp     = 3'd3; //Wait until main computation is done
localparam LoadAcc      = 3'd4; //Load accumulator with final result
localparam WaitNextData2= 3'd5; //Wait for SPI ready signal to be disabled
localparam WaitData2    = 3'd6; //Wait SPI reception of second operand for MAC
localparam WaitMPY      = 3'h7; //Wait until multiplication is done

// State register
reg [2:0] state;
reg [2:0] next_state;

//Update state
always @(posedge clk) begin
    if (rst)
        state <= Idle;
    else
        state <= next_state;
end

// Logic of the next state and outputs
always @(*) begin
    next_state  = state;

    loadA = 1'b0;
    loadB  = 1'b0;
    resetACC = 1'b0;
    loadACC = 1'b0;
    loadPISO = 1'b0;
    en_addsub = 1'b0;
    en_mpy = 1'b0;
    
    case (state)
        Idle: begin
            loadPISO = 1'b1;
            resetACC = 1'b1;
            if (!SS) 
                next_state = WaitNextData1;
        end

        WaitNextData1: begin
            resetACC = 1'b0;
            loadPISO = 1'b1;
            if (!ready_sipo) 
                next_state = WaitData1;
            else if (SS)
                next_state = Idle;
        end

        WaitData1: begin
            loadA = 1'b1;
            loadPISO = 1'b0;
            if (ready_sipo) 
                next_state = WaitNextData2;
            else if (SS)
                next_state = Idle; 
        end

        WaitComp: begin
            loadA = 1'b0;
            en_addsub = 1'b1;
            en_mpy = 1'b0;
            if (ready_op)
                next_state = LoadAcc;
        end

        LoadAcc: begin
            en_addsub = 1'b0;
            en_mpy = 1'b0;
            loadACC = 1'b1;
            next_state = WaitNextData1;
        end

        WaitNextData2: begin
            loadA = 1'b0;
            loadPISO = 1'b1;
            if (!ready_sipo) 
                next_state = WaitData2;
            else if (SS)
                next_state = Idle;
        end

        WaitData2: begin
            loadB = 1'b1;
            if (ready_sipo) begin 
                next_state = WaitMPY;
            end
            else if (SS)
                next_state = Idle; 
        end

        WaitMPY: begin
            loadB = 1'b0;
            en_mpy = 1'b1;
            if (ready_mpy)
                next_state = WaitComp; 
        end

        default: begin
            next_state = Idle;
        end
    endcase

end

endmodule


//------------------------------------------------------
//Parametrizable register with synchronous rest and load 
//------------------------------------------------------

module register #(parameter N=16) (
    input  wire clk,
    input  wire rst,
    input  wire load,
    input  wire [N-1:0] d,
    output reg  [N-1:0] q
);

always @(posedge clk) begin
    if (rst)
        q <= {N{1'b0}};
    else if (load)
        q <= d;
end

endmodule


//------------------------------------------------------
// SPI interface
// MSB-first, SS is active low
// SCLK low on idle, data sampled on positive edge SCLK  
//------------------------------------------------------

module spi_controller #(
    parameter WIDTH = 16
)(
    input  clk,        // Master clock
    input  reset,
    input  sclk,       // SPI clock
    input  ss,         // Slave Select (active low)
    input  mosi,       // Serial data input
    output miso,       // Serial data output

    input  load_tx,               // Load register for transmission
    input  [WIDTH-1:0] data_tx,   // Transmitted data
    output [WIDTH-1:0] data_rx,   // Received data
    output ready         // Set when a word is complete 
);

wire clk_counter;

spi_bit_counter #(.WIDTH(WIDTH)) u_bit_counter(
    .sclk(!clk_counter),
    .ss(ss),
    .ready(ready) 
);

spi_piso_sipo #(.WIDTH(WIDTH)) u_piso_sipo(
    .clk(clk),
    .reset(reset),
    .sclk(sclk),
    .ss(ss),
    .miso(miso),
    .mosi(mosi),
    .load(load_tx),
    .data_in(data_tx),
    .data_out(data_rx),
    .clk_out(clk_counter)
);

endmodule


//------------------------------------------------------
// Bit counter for SPI interface
//------------------------------------------------------

module spi_bit_counter #(
    parameter WIDTH = 16
)(
    input  sclk,       // SPI clock
    input  ss,         // Slave Select (active low)
    output reg ready   // Set when bit count = WIDTH-1 
);

// bit counter
reg [$clog2(WIDTH)-1:0] bit_count;

always @(posedge sclk or posedge ss) begin
    if (ss) begin
        bit_count <= 0;
        ready <= 1'b0;
    end
    else begin
        // Bit counter
        if (bit_count == WIDTH-1) begin
            bit_count <= 0;
            ready <= 1'b1;
        end
        else begin
            bit_count <= bit_count + 1'b1;
            ready <= 1'b0;
        end
    end
end

endmodule

//------------------------------------------------------
// Parallel-Input Serial-Output(PISO) and 
//   Serial-Input Parallel-Output(SIPO) Register
// for the SPI interface
// MSB-first, SS is active low
// SCLK low on idle, data sampled on positive edge SCLK  
//------------------------------------------------------

module spi_piso_sipo #(
    parameter WIDTH = 16
)(
    input  clk,
    input  reset,
    input  sclk,       // SPI clock
    output miso,       // Serial data output
    input  mosi,       // Serial data input
    input  ss,         // Slave Select (active low)
    input  load,       // Load PISO (active high)
    input  [WIDTH-1:0] data_in,   // Data to be transmitted
    output [WIDTH-1:0] data_out,  // Output shift register
    output clk_out     // Output clock to drive the bit counter
);

reg [WIDTH-1:0] shift_reg;  // Shift register
reg [1:0] state_sipo;       // FSM for shift register. 
reg [1:0] next_sipo_state;  // Shifts are always in rising edge of SCLK and Loads in falling edges of SCLK
reg en_shift;   //Internal signals to control when shift and load 
reg en_load;
reg miso_t;

// Update state for SIPO/PISO register
always @(posedge clk) begin
    if (reset) begin 
        state_sipo <= 2'b00;
    end else begin
        state_sipo <= next_sipo_state;
    end
end

// Update next state for SIPO/PISO register
always @(*) begin
    next_sipo_state  = state_sipo;
    en_shift = 1'b0;
    en_load  = 1'b0;
    case (state_sipo)
        2'b00: begin
            if (!ss & sclk) next_sipo_state = 2'b01;
            end
        2'b01: begin
            en_shift = 1'b1;
            next_sipo_state = 2'b10;
            end
        2'b10: begin
            if (!sclk) next_sipo_state = 2'b11;
        end
        2'b11: begin
            en_load = 1'b1;
            next_sipo_state = 2'b00;
            end
    endcase
end

// Update shift register
always @(posedge clk) begin
    if (reset)  
        shift_reg <= {WIDTH{1'b0}};
    else if (en_load & load) 
        shift_reg <= data_in;
    else if (en_shift) // Shift MSB first
        shift_reg <= { shift_reg[WIDTH-2:0], mosi };
end

//assign miso = shift_reg[WIDTH-1];
assign data_out = shift_reg;
assign clk_out = en_shift;

always @(negedge en_load or posedge reset) begin
    if (reset)
        miso_t <= 1'b0;
    else
        miso_t <= shift_reg[WIDTH-1];
end

assign miso = miso_t;

endmodule