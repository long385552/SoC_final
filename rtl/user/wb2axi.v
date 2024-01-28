`timescale 1ns / 1ps
module wb2axi
#(  parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num    = 11
)
(   
    //--------------------------------------------------
    // Global
    input   wire                     clk,
    input   wire                     rst,
    //--------------------------------------------------
    // WB decoded
    input   wire                     fir_en,
    input   wire                     fir_we,
    input   wire [(pADDR_WIDTH-1):0] fir_addr,
    input   wire [(pDATA_WIDTH-1):0] fir_dat_i,
    output  wire                     fir_valid,
    output  wire [(pDATA_WIDTH-1):0] fir_dat_o,
    //--------------------------------------------------
    // AXI-ST master - X
    output wire                     ss_tready,
    input wire                     ss_tvalid,
    input wire                     ss_tlast,
    input wire [(pDATA_WIDTH-1):0] ss_tdata,
    //--------------------------------------------------
    // AXI-ST slave - Y
    input  wire                     sm_tready,
    output wire                     sm_tvalid,
    output wire                     sm_tlast,
    output wire [(pDATA_WIDTH-1):0] sm_tdata
);
    //================================================================
    //  INTEGER / GENVAR / PARAMETER
    //================================================================
    // FSM
    localparam  S_IDLE   = 3'd0,    // wait for FIR enable
                S_LT_W_0 = 3'd1,    // wb to lite write
                S_LT_W_1 = 3'd2,
                S_LT_R_0 = 3'd3,    // wb to lite read
                S_LT_R_1 = 3'd4,
                S_DONE   = 3'd5;    // axi transcation done, pull up fir_valid

    //================================================================
    // INTERNAL WIRES / REGS
    //================================================================
    // FSM
    reg [2:0] cs, ns;
    // X tlast counter for data length = 64
    reg [5:0] tlast_counter;
    // AXI-lite master write
    wire                     awready;
    wire                     awvalid;
    wire [(pADDR_WIDTH-1):0] awaddr;
    wire                     wready;
    wire                     wvalid;  
    wire [(pDATA_WIDTH-1):0] wdata;
    // AXI-lite master read
    wire                     arready;
    wire                     arvalid;
    wire [(pADDR_WIDTH-1):0] araddr;
    wire                     rready;
    wire                     rvalid;
    wire [(pDATA_WIDTH-1):0] rdata;
    // bram for TAP RAM
    wire   [3:0]             tap_WE;
    wire                     tap_EN;
    wire [(pDATA_WIDTH-1):0] tap_Di;
    wire [(pADDR_WIDTH-1):0] tap_A;
    wire [(pDATA_WIDTH-1):0] tap_Do;
    // bram for DATA RAM
    wire  [3:0]              data_WE;
    wire                     data_EN;
    wire [(pDATA_WIDTH-1):0] data_Di;
    wire [(pADDR_WIDTH-1):0] data_A;
    wire [(pDATA_WIDTH-1):0] data_Do;

    // // AXI-ST master - X
    // wire                     ss_tready;
    // wire                     ss_tvalid;
    // wire                     ss_tlast;
    // wire [(pDATA_WIDTH-1):0] ss_tdata;
    // //--------------------------------------------------
    // // AXI-ST slave - Y
    // wire                     sm_tready;
    // wire                     sm_tvalid;
    // wire                     sm_tlast;
    // wire [(pDATA_WIDTH-1):0] sm_tdata;
    //================================================================
    //  INSTANCES
    //================================================================
    // FIR
    fir_lab4 user_fir (
        // Global
        .axis_clk(clk),
        .axis_rst_n(~rst),  // cuz fir is rst_n
        // AXI-lite slave write
        .awready(awready),
        .awvalid(awvalid),
        .awaddr(awaddr),
        .wready(wready),
        .wvalid(wvalid),  
        .wdata(wdata),
        // AXI-lite slave read
        .arready(arready),
        .arvalid(arvalid),
        .araddr(araddr),
        .rready(rready),
        .rvalid(rvalid),
        .rdata(rdata),
        // AXI-ST slave - X
        .ss_tready(ss_tready),
        .ss_tvalid(ss_tvalid),
        .ss_tlast(ss_tlast),
        .ss_tdata(ss_tdata),
        // AXI-ST master - Y
        .sm_tready(sm_tready),
        .sm_tvalid(sm_tvalid),
        .sm_tlast(sm_tlast),
        .sm_tdata(sm_tdata),
        // bram for TAP RAM
        .tap_WE(tap_WE),
        .tap_EN(tap_EN),
        .tap_Di(tap_Di),
        .tap_A(tap_A),
        .tap_Do(tap_Do),
        // bram for X RAM
        .data_WE(data_WE),
        .data_EN(data_EN),
        .data_Di(data_Di),
        .data_A(data_A),
        .data_Do(data_Do)
    );
    // TAP RAM
    bram11 tap_ram (
        .clk(clk),
        .we(tap_WE[0]),
        .re(tap_EN),
        .waddr(tap_A),
        .raddr(tap_A),
        .wdi(tap_Di),
        .rdo(tap_Do)
    );
    // DATA RAM
    bram11 data_ram (
        .clk(clk),
        .we(data_WE[0]),
        .re(data_EN),
        .waddr(data_A),
        .raddr(data_A),
        .wdi(data_Di),
        .rdo(data_Do)
    );

    //================================================================
    // FSM
    //================================================================
    // reg [2:0] cs
    always @(posedge clk) begin
        if (rst)
            cs <= 3'd0;
        else
            cs <= ns;
    end
    // reg [2:0] ns
    always @(*) begin
        ns = cs;
        case (cs)
            S_IDLE: begin
                if (fir_en) begin
                    ns = (fir_we)? S_LT_W_0 : S_LT_R_0;
                end
                else
                    ns = S_IDLE;
            end
            S_LT_W_0:   ns = (awready)  ? S_LT_W_1 : S_LT_W_0;
            S_LT_W_1:   ns = (wready)   ? S_DONE   : S_LT_W_1;
            S_LT_R_0:   ns = (arready)  ? S_LT_R_1 : S_LT_R_0;
            S_LT_R_1:   ns = (rvalid)   ? S_DONE   : S_LT_R_1;
            S_DONE:     ns = S_IDLE;
        endcase
    end

    //================================================================
    // WB decoded
    //================================================================
    // output  wire                     fir_valid,
    assign fir_valid = (ns == S_DONE);
    // output  wire [(pDATA_WIDTH-1):0] fir_dat_o,
    assign fir_dat_o = rdata;

    //================================================================
    // AXI-lite master write
    //================================================================
    // output  wire                     awvalid
    assign awvalid = (cs == S_LT_W_0);
    // output  wire [(pADDR_WIDTH-1):0] awaddr
    assign awaddr  = fir_addr;
    // output  wire                     wvalid
    assign wvalid  = (cs == S_LT_W_1);
    // output  wire [(pDATA_WIDTH-1):0] wdata
    assign wdata   = fir_dat_i;

    //================================================================
    // AXI-lite master read
    //================================================================
    // output  wire                     arvalid
    assign arvalid = (cs == S_LT_R_0);
    // output  wire [(pADDR_WIDTH-1):0] araddr
    assign araddr  = fir_addr;
    // output  wire                     rready
    assign rready  = (cs == S_LT_R_1);


endmodule