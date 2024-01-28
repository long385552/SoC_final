`timescale 1ns / 1ps
module qsort
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
    output  reg  [(pDATA_WIDTH-1):0] sm_tdata
);
    localparam WAIT = 1'b0, DONE = 1'b1;

    reg cs, ns;
    reg [3:0] count;
    reg [(pDATA_WIDTH-1):0] in_reg [0:9];
    wire [(pDATA_WIDTH-1):0] stage_7 [0:9];

    wire [(pDATA_WIDTH-1):0] stage_1 [0:9];
    wire [(pDATA_WIDTH-1):0] stage_2 [0:9];
    wire [(pDATA_WIDTH-1):0] stage_3 [0:9];
    wire [(pDATA_WIDTH-1):0] stage_4 [0:9];
    wire [(pDATA_WIDTH-1):0] stage_5 [0:9];
    wire [(pDATA_WIDTH-1):0] stage_6 [0:9];

    // FSM
    always @(posedge clk) begin
        if (rst)
            cs <= WAIT;
        else
            cs <= ns;
    end
    always @(*) begin
        ns = WAIT;
        case(cs)
            WAIT: ns = (count == 4'd10)? DONE : WAIT;
            DONE: ns = (count == 4'd10)? WAIT : DONE;
        endcase
    end

    // Handshake counter with more 1T delay for pipeline
    always @(posedge clk) begin
        if (rst | (count == 4'd10))
            count <= 4'd0;
        else if ((cs == WAIT) & (ss_tvalid & ss_tready))
            count <= count + 1'b1;
        else if ((cs == DONE) & (sm_tvalid & sm_tready))
            count <= count + 1'b1;
        else
            count <= count;
    end

    // AXI-ST slave
    assign ss_tready = (cs == WAIT) & (count < 4'd10);

    // AXI-ST master
    assign sm_tvalid = (cs == DONE) & (count < 4'd10);
    always @(*) begin
       sm_tdata <= 32'd0;
       case(count)
           4'd0:    sm_tdata <= stage_7[0];
           4'd1:    sm_tdata <= stage_7[1];
           4'd2:    sm_tdata <= stage_7[2];
           4'd3:    sm_tdata <= stage_7[3];
           4'd4:    sm_tdata <= stage_7[4];
           4'd5:    sm_tdata <= stage_7[5];
           4'd6:    sm_tdata <= stage_7[6];
           4'd7:    sm_tdata <= stage_7[7];
           4'd8:    sm_tdata <= stage_7[8];
           4'd9:    sm_tdata <= stage_7[9];
           4'd10:   sm_tdata <= stage_7[0];
           default: sm_tdata <= stage_7[0];
       endcase
    end

    // 10 inputs 7 stages QSORT
    // input register
    always @(posedge clk) begin
        if (rst) begin
            in_reg[0] <= 32'd0;
            in_reg[1] <= 32'd0;
            in_reg[2] <= 32'd0;
            in_reg[3] <= 32'd0;
            in_reg[4] <= 32'd0;
            in_reg[5] <= 32'd0;
            in_reg[6] <= 32'd0;
            in_reg[7] <= 32'd0;
            in_reg[8] <= 32'd0;
            in_reg[9] <= 32'd0;
        end
        else if (ss_tvalid & ss_tready) begin
            in_reg[0] <= ss_tdata;
            in_reg[1] <= in_reg[0];
            in_reg[2] <= in_reg[1];
            in_reg[3] <= in_reg[2];
            in_reg[4] <= in_reg[3];
            in_reg[5] <= in_reg[4];
            in_reg[6] <= in_reg[5];
            in_reg[7] <= in_reg[6];
            in_reg[8] <= in_reg[7];
            in_reg[9] <= in_reg[8];
        end
        else begin
            in_reg[0] <= in_reg[0];
            in_reg[1] <= in_reg[1];
            in_reg[2] <= in_reg[2];
            in_reg[3] <= in_reg[3];
            in_reg[4] <= in_reg[4];
            in_reg[5] <= in_reg[5];
            in_reg[6] <= in_reg[6];
            in_reg[7] <= in_reg[7];
            in_reg[8] <= in_reg[8];
            in_reg[9] <= in_reg[9];
        end
    end

    // stage 1: (0,1) (2,5) (3,6) (4,7) (8,9)
    assign stage_1[0] = (in_reg[0] > in_reg[1])? in_reg[0] : in_reg[1];
    assign stage_1[1] = (in_reg[0] > in_reg[1])? in_reg[1] : in_reg[0];
    assign stage_1[2] = (in_reg[2] > in_reg[5])? in_reg[2] : in_reg[5];
    assign stage_1[3] = (in_reg[3] > in_reg[6])? in_reg[3] : in_reg[6];
    assign stage_1[4] = (in_reg[4] > in_reg[7])? in_reg[4] : in_reg[7];
    assign stage_1[5] = (in_reg[2] > in_reg[5])? in_reg[5] : in_reg[2];
    assign stage_1[6] = (in_reg[3] > in_reg[6])? in_reg[6] : in_reg[3];
    assign stage_1[7] = (in_reg[4] > in_reg[7])? in_reg[7] : in_reg[4];
    assign stage_1[8] = (in_reg[8] > in_reg[9])? in_reg[8] : in_reg[9];
    assign stage_1[9] = (in_reg[8] > in_reg[9])? in_reg[9] : in_reg[8];

    // stage 2: (0,6) (1,8) (2,4) (3,9) (5,7)
    assign stage_2[0] = (stage_1[0] > stage_1[6])? stage_1[0] : stage_1[6];
    assign stage_2[1] = (stage_1[1] > stage_1[8])? stage_1[1] : stage_1[8];
    assign stage_2[2] = (stage_1[2] > stage_1[4])? stage_1[2] : stage_1[4];
    assign stage_2[3] = (stage_1[3] > stage_1[9])? stage_1[3] : stage_1[9];
    assign stage_2[4] = (stage_1[2] > stage_1[4])? stage_1[4] : stage_1[2];
    assign stage_2[5] = (stage_1[5] > stage_1[7])? stage_1[5] : stage_1[7];
    assign stage_2[6] = (stage_1[0] > stage_1[6])? stage_1[6] : stage_1[0];
    assign stage_2[7] = (stage_1[5] > stage_1[7])? stage_1[7] : stage_1[5];
    assign stage_2[8] = (stage_1[1] > stage_1[8])? stage_1[8] : stage_1[1];
    assign stage_2[9] = (stage_1[3] > stage_1[9])? stage_1[9] : stage_1[3];

    // stage 3: (0,2) (1,3) (4,5) (6,8) (7,9)
    assign stage_3[0] = (stage_2[0] > stage_2[2])? stage_2[0] : stage_2[2];
    assign stage_3[1] = (stage_2[1] > stage_2[3])? stage_2[1] : stage_2[3];
    assign stage_3[2] = (stage_2[0] > stage_2[2])? stage_2[2] : stage_2[0];
    assign stage_3[3] = (stage_2[1] > stage_2[3])? stage_2[3] : stage_2[1];
    assign stage_3[4] = (stage_2[4] > stage_2[5])? stage_2[4] : stage_2[5];
    assign stage_3[5] = (stage_2[4] > stage_2[5])? stage_2[5] : stage_2[4];
    assign stage_3[6] = (stage_2[6] > stage_2[8])? stage_2[6] : stage_2[8];
    assign stage_3[7] = (stage_2[7] > stage_2[9])? stage_2[7] : stage_2[9];
    assign stage_3[8] = (stage_2[6] > stage_2[8])? stage_2[8] : stage_2[6];
    assign stage_3[9] = (stage_2[7] > stage_2[9])? stage_2[9] : stage_2[7];

    // stage 4: (0,1) (2,7) (3,5) (4,6) (8,9)
    assign stage_4[0] = (stage_3[0] > stage_3[1])? stage_3[0] : stage_3[1];
    assign stage_4[1] = (stage_3[0] > stage_3[1])? stage_3[1] : stage_3[0];
    assign stage_4[2] = (stage_3[2] > stage_3[7])? stage_3[2] : stage_3[7];
    assign stage_4[3] = (stage_3[3] > stage_3[5])? stage_3[3] : stage_3[5];
    assign stage_4[4] = (stage_3[4] > stage_3[6])? stage_3[4] : stage_3[6];
    assign stage_4[5] = (stage_3[3] > stage_3[5])? stage_3[5] : stage_3[3];
    assign stage_4[6] = (stage_3[4] > stage_3[6])? stage_3[6] : stage_3[4];
    assign stage_4[7] = (stage_3[2] > stage_3[7])? stage_3[7] : stage_3[2];
    assign stage_4[8] = (stage_3[8] > stage_3[9])? stage_3[8] : stage_3[9];
    assign stage_4[9] = (stage_3[8] > stage_3[9])? stage_3[9] : stage_3[8];

    // stage 5:　(1,2) (3,4) (5,6) (7,8)
    assign stage_5[0] = stage_4[0];
    assign stage_5[1] = (stage_4[1] > stage_4[2])? stage_4[1] : stage_4[2];
    assign stage_5[2] = (stage_4[1] > stage_4[2])? stage_4[2] : stage_4[1];
    assign stage_5[3] = (stage_4[3] > stage_4[4])? stage_4[3] : stage_4[4];
    assign stage_5[4] = (stage_4[3] > stage_4[4])? stage_4[4] : stage_4[3];
    assign stage_5[5] = (stage_4[5] > stage_4[6])? stage_4[5] : stage_4[6];
    assign stage_5[6] = (stage_4[5] > stage_4[6])? stage_4[6] : stage_4[5];
    assign stage_5[7] = (stage_4[7] > stage_4[8])? stage_4[7] : stage_4[8];
    assign stage_5[8] = (stage_4[7] > stage_4[8])? stage_4[8] : stage_4[7];
    assign stage_5[9] = stage_4[9];

    // stage 6: (1,3) (2,4) (5,7) (6,8)
    assign stage_6[0] = stage_5[0];
    assign stage_6[1] = (stage_5[1] > stage_5[3])? stage_5[1] : stage_5[3];
    assign stage_6[2] = (stage_5[2] > stage_5[4])? stage_5[2] : stage_5[4];
    assign stage_6[3] = (stage_5[1] > stage_5[3])? stage_5[3] : stage_5[1];
    assign stage_6[4] = (stage_5[2] > stage_5[4])? stage_5[4] : stage_5[2];
    assign stage_6[5] = (stage_5[5] > stage_5[7])? stage_5[5] : stage_5[7];
    assign stage_6[6] = (stage_5[6] > stage_5[8])? stage_5[6] : stage_5[8];
    assign stage_6[7] = (stage_5[5] > stage_5[7])? stage_5[7] : stage_5[5];
    assign stage_6[8] = (stage_5[6] > stage_5[8])? stage_5[8] : stage_5[6];
    assign stage_6[9] = stage_5[9];

    // stage 7: (2,3) (4,5) (6,7)
    assign stage_7[0] = stage_6[0];
    assign stage_7[1] = stage_6[1];
    assign stage_7[2] = (stage_6[2] > stage_6[3])? stage_6[2] : stage_6[3];
    assign stage_7[3] = (stage_6[2] > stage_6[3])? stage_6[3] : stage_6[2];
    assign stage_7[4] = (stage_6[4] > stage_6[5])? stage_6[4] : stage_6[5];
    assign stage_7[5] = (stage_6[4] > stage_6[5])? stage_6[5] : stage_6[4];
    assign stage_7[6] = (stage_6[6] > stage_6[7])? stage_6[6] : stage_6[7];
    assign stage_7[7] = (stage_6[6] > stage_6[7])? stage_6[7] : stage_6[6];
    assign stage_7[8] = stage_6[8];
    assign stage_7[9] = stage_6[9];


endmodule