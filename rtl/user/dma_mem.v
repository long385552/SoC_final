`timescale 1ns / 1ps
module dma_mem
(   
    //--------------------------------------------------
    // Global
    input   wire                     clk,
    input   wire                     rst,
    //--------------------------------------------------
    // Wishbone
    input  wire [31:0]               wb_addr,
    input  wire [31:0]               wb_data_i,
    input  wire [3:0]                wb_we,
    input  wire                      wb_en,     // wb_en keep high until wb_ack high 
    output wire [31:0]               wb_data_o,
    output wire                      wb_ack,
    //--------------------------------------------------
    // DMA (always ready for DMA access)
    input  wire [31:0]               dma_addr,
    input  wire [31:0]               dma_data_i,
    input  wire                      dma_we,
    input  wire                      dma_en,    // dma_en high 1T for 1 data
    output wire [31:0]               dma_data_o,
    output wire                      dma_read_ack   // dma write dma_mem don't use ack
);
    //==================================================
    // PARAMETERS & INTERGER
    //==================================================
    integer i;

    //==================================================
    // INTERNAL REG & WIRES
    //==================================================
    // WIRE
    wire            dma_bram_en;
    wire            dma_bram_we;
    wire [3:0]      dma_bram_sel;
    wire [31:0]     dma_bram_addr;
    wire [31:0]     dma_bram_data_i;
    wire            dma_bram_ack;
    wire [31:0]     dma_bram_data_o;
    wire            wb_write;
    wire            wb_read;
    wire            dma_write;
    wire            dma_read;
    // REG
    reg [3:0]       wb_read_count;
    reg             wb_read_reg;
    reg [10:0]       dma_read_delay;

    //==================================================
    // INSTANCES
    //==================================================
    exmem_pipeline dma_exmem
    (
    // input
    .clk(clk),
    .rst(rst),		            // active high (from WB)
    .stb(dma_bram_en),		    // command strobe -request
    .we(dma_bram_we),		    // 1: write, 0: read
    .sel(dma_bram_sel),		    // byte-enable
    .dat_i(dma_bram_data_i),	// data in
    .addr(dma_bram_addr),		// address in
    // output
    .ack(dma_bram_ack),		    // ready
    .dat_o(dma_bram_data_o)	    // data out
    );

    //==================================================
    // dma_bram control
    //==================================================
    assign dma_bram_en      = wb_en | dma_en;
    assign dma_bram_we      = (dma_en)? dma_we : wb_we;
    assign dma_bram_sel     = (dma_bram_we)? 4'b1111 : wb_we;
    assign dma_bram_data_i  = (dma_en)? dma_data_i : wb_data_i;
    assign dma_bram_addr    = (dma_en)? dma_addr : wb_addr;

    //==================================================
    // WB access
    //==================================================
    // WB internal logic
    assign wb_write = (|wb_we) & wb_en;
    assign wb_read  = ~(|wb_we) & wb_en;

    always @(posedge clk) begin
        if (rst)
            wb_read_count <= 4'd0;
        else if (wb_read_reg)
            wb_read_count <= wb_read_count + 1'b1;
        else
            wb_read_count <= 4'd0;
    end

    always @(posedge clk) begin
        if (rst | (wb_read_count == 4'd10))
            wb_read_reg <= 1'b0;
        else if (wb_read & (~dma_en))   // wb access available, remeber that and pull up ack after 10T
            wb_read_reg <= 1'b1;
        else
            wb_read_reg <= wb_read_reg;
    end

    // To WB output
    assign wb_data_o = dma_bram_data_o;
    assign wb_ack    = (wb_write & (~dma_en)) | (wb_read_count == 4'd10);   // wb甚麼時候可以寫入

    //==================================================
    // DMA access
    //==================================================
    // DMA internal logic
    assign dma_write = (dma_we) & dma_en;
    assign dma_read  = ~(dma_we) & dma_en;

    always @(posedge clk) begin
        if (rst) begin
            dma_read_delay <= 10'd0;
        end
        else begin
            dma_read_delay[0] <= dma_read;
            dma_read_delay[1] <= dma_read_delay[0];   // Unrolled loop
            dma_read_delay[2] <= dma_read_delay[1];   // Unrolled loop
            dma_read_delay[3] <= dma_read_delay[2];   // Unrolled loop
            dma_read_delay[4] <= dma_read_delay[3];   // Unrolled loop
            dma_read_delay[5] <= dma_read_delay[4];   // Unrolled loop
            dma_read_delay[6] <= dma_read_delay[5];   // Unrolled loop
            dma_read_delay[7] <= dma_read_delay[6];   // Unrolled loop
            dma_read_delay[8] <= dma_read_delay[7];   // Unrolled loop
            dma_read_delay[9] <= dma_read_delay[8];   // Unrolled loop
            dma_read_delay[10] <= dma_read_delay[9];   // Unrolled loop
        end 
    end



    // To DMA output
    assign dma_data_o   = dma_bram_data_o;
    assign dma_read_ack = dma_read_delay[10];



endmodule