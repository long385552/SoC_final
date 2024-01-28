`timescale 1ns / 1ps
module mm
#(
    parameter pDATA_WIDTH = 32
)
(
    // Global
    input   wire                     clk,
    input   wire                     rst,
    // AXI-ST slave
    output  wire                     ss_tready,
    input   wire                     ss_tvalid,
    input   wire [(pDATA_WIDTH-1):0] ss_tdata,
    // AXI-ST master
    input   wire                     sm_tready,
    output  wire                     sm_tvalid,
    output  wire [(pDATA_WIDTH-1):0] sm_tdata
);

    localparam  RESET = 2'd0, INIT = 2'd1, CALC = 2'd2, DONE = 2'd3;

    integer i;

    reg  A_done, B_done, idle_reg;
    reg  [(pDATA_WIDTH-1):0]    A1_RAM [0:3];   // 0
    reg  [(pDATA_WIDTH-1):0]    A2_RAM [0:3];   // 4
    reg  [(pDATA_WIDTH-1):0]    A3_RAM [0:3];   // 8
    reg  [(pDATA_WIDTH-1):0]    A4_RAM [0:3];   // 12
    reg  [(pDATA_WIDTH-1):0]    B1_RAM [0:3];
    reg  [(pDATA_WIDTH-1):0]    B2_RAM [0:3];
    reg  [(pDATA_WIDTH-1):0]    B3_RAM [0:3];
    reg  [(pDATA_WIDTH-1):0]    B4_RAM [0:3];
    reg [4:0]   a_counter, a_next_counter;
    reg [4:0]   b_counter, b_next_counter;
	reg [1:0]   cs, ns;
    reg [31:0] output_reg;
    reg  [4:0]  C1_counter;
    reg  [31:0] C1[3:0], C2[3:0], C3[3:0], C4[3:0];

    wire nA_done, nB_done;
    wire [31:0] C1_mul, C2_mul, C3_mul, C4_mul;

    assign ss_tready = (cs==INIT);
    assign sm_tvalid = (cs==DONE);
    
    assign nA_done = (~A_done & a_counter==5'd16) ? 1 : A_done;
    assign nB_done = (~B_done & b_counter==5'd16) ? 1 : B_done;
    
    always @(posedge clk) begin
		if (rst) begin
			A_done <= 0;
            B_done <= 0;
            idle_reg <= 0;
		end
		else begin
			A_done <= nA_done;
            B_done <= nB_done;
            idle_reg <= ((cs==DONE) & (C1_counter)) ? 1 : idle_reg;;
		end
    end

    always @(posedge clk) begin
		if (rst) begin
			cs <= RESET;
            a_counter <= 0;
            b_counter <= 0;
		end
		else begin
			cs <= ns;
            a_counter <= a_next_counter;
            b_counter <= b_next_counter;
		end
	end

    // counter   
    always @(*) begin 
        if (cs==RESET) begin
            a_next_counter=0;
            b_next_counter=0;
        end
        else if (cs==INIT) begin
            if (ss_tvalid) begin
                if (~A_done) begin
                    a_next_counter = a_counter + 1;
                end
                else begin
                    b_next_counter = b_counter + 1;                 
                end
            end
        end
    end
    

    always @(*) begin 
        case (cs)
            RESET: begin 
                if (((cs==DONE) & (C1_counter)) ? 1 : idle_reg) begin
                    ns = RESET;
                end 
                else begin
                    ns = INIT;
                end
            end
            INIT: begin 
                if (A_done & B_done) begin
                    ns = CALC;
                end
                else begin
                    ns = INIT;
                end
            end
            CALC: begin 
                if (C1_counter==16) begin
                    ns = DONE;
                end
                else begin
                    ns = CALC;
                end
            end
            DONE: begin 
                if (C1_counter==16) begin
                    ns = RESET;
                end
                else begin
                    ns = DONE;
                end
            end
            default: begin 
                ns = RESET;
            end
        endcase
    end

    always @(posedge clk) begin 
        if (rst) begin
            for (i=0;i<4;i=i+1)begin
	            A1_RAM[i] <= 0;
                A2_RAM[i] <= 0;
                A3_RAM[i] <= 0;
                A4_RAM[i] <= 0;
                B1_RAM[i] <= 0;
                B2_RAM[i] <= 0;
                B3_RAM[i] <= 0;
                B4_RAM[i] <= 0;
	        end
	        C1_counter <= 0;
        end
        else if (cs==INIT & ss_tvalid) begin
            if (~A_done) begin
                if (a_counter[3:2]==2'd0) begin
                    A1_RAM[a_counter[1:0]] <= ss_tdata;
                end
                else if (a_counter[3:2]==2'd1) begin
                    A2_RAM[a_counter[1:0]] <= ss_tdata;
                end
                else if (a_counter[3:2]==2'd2) begin
                    A3_RAM[a_counter[1:0]] <= ss_tdata;
                end
                else if (a_counter[3:2]==2'd3) begin
                    A4_RAM[a_counter[1:0]] <= ss_tdata;
                end
            end
            else if (A_done & ~B_done) begin
                if (b_counter[1:0]==2'd0) begin
                    B1_RAM[b_counter[3:2]] <= ss_tdata;
                end
                else if (b_counter[1:0]==2'd1) begin
                    B2_RAM[b_counter[3:2]] <= ss_tdata;
                end
                else if (b_counter[1:0]==2'd2) begin
                    B3_RAM[b_counter[3:2]] <= ss_tdata;
                end
                else if (b_counter[1:0]==2'd3) begin
                    B4_RAM[b_counter[3:2]] <= ss_tdata;
                end
            end
        end
        else if (cs==CALC) begin
            for(i = 0; i < 3; i=i+1) begin
                A1_RAM[i] <= A1_RAM[i+1];
                A2_RAM[i] <= A2_RAM[i+1];
                A3_RAM[i] <= A3_RAM[i+1];
                A4_RAM[i] <= A4_RAM[i+1];
                B1_RAM[i] <= B1_RAM[i+1];
                B2_RAM[i] <= B2_RAM[i+1];
                B3_RAM[i] <= B3_RAM[i+1];
                B4_RAM[i] <= B4_RAM[i+1];
            end
            A1_RAM[3] <= A1_RAM[0];
            A2_RAM[3] <= A2_RAM[0];
            A3_RAM[3] <= A3_RAM[0];
            A4_RAM[3] <= A4_RAM[0];
            B1_RAM[3] <= B4_RAM[0];
            B2_RAM[3] <= B1_RAM[0];
            B3_RAM[3] <= B2_RAM[0];
            B4_RAM[3] <= B3_RAM[0];
            C1_counter <= C1_counter + 1;
            if (C1_counter==16) begin
                C1_counter <= 0;
            end
        end
        else if (cs==DONE) begin
            if (sm_tready) begin
                C1_counter <= C1_counter + 1;
            end
        end
    end

    assign C1_mul = A1_RAM[0] * B1_RAM[0];
    assign C2_mul = A2_RAM[0] * B2_RAM[0];
    assign C3_mul = A3_RAM[0] * B3_RAM[0];
    assign C4_mul = A4_RAM[0] * B4_RAM[0];
    
    
    always @(posedge clk) begin
        if (rst) begin
            for(i=0;i<4;i=i+1) begin 
                C1[i]<=0;
                C2[i]<=0;
                C3[i]<=0;
                C4[i]<=0;
            end
        end
        else begin
            if (cs==CALC)begin
                if (C1_counter >>2 == 0)begin
                    C1[0]<=C1[0]+C1_mul;
                    C2[1]<=C2[1]+C2_mul;
                    C3[2]<=C3[2]+C3_mul;
                    C4[3]<=C4[3]+C4_mul;
                end    
                else if (C1_counter >>2 == 1) begin
                    C1[3]<=C1[3]+C1_mul;
                    C2[0]<=C2[0]+C2_mul;
                    C3[1]<=C3[1]+C3_mul;
                    C4[2]<=C4[2]+C4_mul;
                end
                else if (C1_counter >>2 == 2) begin
                    C1[2]<=C1[2]+C1_mul;
                    C2[3]<=C2[3]+C2_mul;
                    C3[0]<=C3[0]+C3_mul;
                    C4[1]<=C4[1]+C4_mul;
                end
                else if (C1_counter >>2 == 3) begin
                    C1[1]<=C1[1]+C1_mul;
                    C2[2]<=C2[2]+C2_mul;
                    C3[3]<=C3[3]+C3_mul;
                    C4[0]<=C4[0]+C4_mul;
                end
            end
        end
    end
    
    assign sm_tdata = (cs==DONE) ? output_reg : 0;

    always @(*) begin 
        if (cs==DONE) begin
            if (sm_tready) begin
                if (C1_counter >>2 == 0)begin
                    output_reg <= C1[C1_counter[1:0]];
                end    
                else if (C1_counter >>2 == 1) begin
                    output_reg <= C2[C1_counter[1:0]];
                end
                else if (C1_counter >>2 == 2) begin
                    output_reg <= C3[C1_counter[1:0]];
                end
                else if (C1_counter >>2 == 3) begin
                    output_reg <= C4[C1_counter[1:0]];
                end
            end
            else begin
                output_reg <= output_reg;
            end
        end
        else begin
            output_reg <= 0;
        end
    end 

endmodule