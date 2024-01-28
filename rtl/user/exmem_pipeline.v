// exmem_pipeline
//    A Memory system in user project area, with the following specificaiton
// Interface timing:  10T latency for read/write access
//          1   2   3   4   5   6   7   8   9   10  11  12  13  14  15  16  17
// clk    |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |   |
// stb    _/---\___/-------\___/-------\_______
// we     _/---\_______/---\___________________
// addr   __a1_____a2__a3_______a4_a5
// dat_i  __d1_________d2_______
// ack(10T)____________________________________/--\____/-------\___/-------\____
// dat_o   _____________________________________________d2__________d4_d5_______
// 

    `define SEL_POS 3:0
    `define DAT_POS 35:4
    `define ADR_POS 67:36
    `define N       10
    
`default_nettype wire

module exmem_pipeline #(
    parameter N = 10
)(
    input         clk,
    input         rst,		// active high (from WB)
    input         stb,		// command strobe -request
    input         we,		// 1: write, 0: read
    input  [3:0]  sel,		// byte-enable
    input  [31:0] dat_i,	// data in
    input  [31:0] addr,		// address in
	
    output        ack,		// ready
    output [31:0] dat_o	    	// data out
    );

    // FIFO for shifting WB request
    reg   [67:0] req_fifo0, req_fifo1, req_fifo2, req_fifo3, req_fifo4, req_fifo5, req_fifo6, req_fifo7, req_fifo8, req_fifo9 ;
    reg  [N-1:0] we_fifo;
    reg  [N-1:0] valid_fifo;
    reg          ack;
    
    // Wishbone INPUT request
    wire  [67:0] req_in;
    
    // BRAM byte enable
    wire   [3:0] byte_en;
    integer i;
    // Initalize FIFO, and perform Shift FIFO
    always @(posedge clk or posedge rst) begin
        if (rst) begin
	       valid_fifo <= `N'b0;
	       we_fifo    <= `N'b0;
        end
        else begin
           valid_fifo <= {stb, valid_fifo[N-1:1]};
           we_fifo    <= {we, we_fifo[N-1:1]};
        end
    end
    
    assign req_in = {addr, dat_i, sel};
    
    // Put Wishbone input request into FIFO
    always @(posedge clk) begin
        if(rst) begin
            req_fifo0 <= 0;
            req_fifo1 <= 0;
            req_fifo2 <= 0;
            req_fifo3 <= 0;
            req_fifo4 <= 0;
            req_fifo5 <= 0;
            req_fifo6 <= 0;
            req_fifo7 <= 0;
            req_fifo8 <= 0;
            req_fifo9 <= 0;
        end else begin
            req_fifo9 <= req_in;
            req_fifo8 <= req_fifo9;
            req_fifo7 <= req_fifo8;
            req_fifo6 <= req_fifo7;
            req_fifo5 <= req_fifo6;
            req_fifo4 <= req_fifo5;           
            req_fifo3 <= req_fifo4;
            req_fifo2 <= req_fifo3;
            req_fifo1 <= req_fifo2;
            req_fifo0 <= req_fifo1;
        //     req_fifo[N-1] <= req_in;
        //     for (i = 0; i < N-2; i = i + 1) begin         
        //         req_fifo[i] <= req_fifo[i + 1];
        // end
        end
    end
    

    // Shift the FIFO
    // Unroll to N-2, since the FIFO[N-1] has been assign to input request
    // always @(posedge clk) begin
    //     for (i = 0; i < N-2; i = i + 1) begin         
    //         req_fifo[i] <= req_fifo[i + 1];
    //     end
    // end
    
    // ACK signal is generated 1T after valid_fifo[0] = 1,
    // because BRAM read access takes 1T module bram
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            ack <= 0;
        end
        else begin
            ack <= valid_fifo[0];
        end
    end

    assign byte_en = req_fifo0[`SEL_POS] & {4{we_fifo[0]}};
    
    bram data_bram (
        .CLK (clk),
        .WE0 (byte_en),
        .EN0 (valid_fifo[0]),
        .Di0 (req_fifo0[`DAT_POS]),
        .Do0 (dat_o),
        .A0  (req_fifo0[`ADR_POS])
    );

endmodule

`default_nettype wire