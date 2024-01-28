`timescale 1ns / 1ps
module dma_engine 
(   
    //--------------------------------------------------
    // Global
    input   wire                     clk,
    input   wire                     rst,
    //--------------------------------------------------
    // Wishbonreadye
    input  wire [11:0]               wb_addr,       // only use 12 bits addr like FIR
    input  wire [31:0]               wb_data_i,
    input  wire                      wb_we,
    input  wire                      wb_en,
    output wire [31:0]               wb_data_o,
    output wire                      wb_ack,
    //--------------------------------------------------
    // AXI-ST master - X
    input  wire                     ss_tready,
    output wire                     ss_tvalid, 
    output wire                     ss_tlast,
    output wire [31:0]              ss_tdata,
    //--------------------------------------------------
    // AXI-ST slave - Y
    output wire                     sm_tready, 
    input  wire                     sm_tvalid,  
    input  wire                     sm_tlast, 
    input  wire [31:0]              sm_tdata,
    //--------------------------------------------------
    // DMA MEM
    output  wire [31:0]             dma_addr,
    output  wire [31:0]             dma_data_i,
    output  wire                    dma_we,
    output  wire                    dma_en,    // dma_en high 1T for 1 data
    input   wire [31:0]             dma_data_o,
    input   wire                    dma_read_ack,
    // DMA IRQ
    output wire                     dma_irq
);
    //==================================================
    // PARAMETERS & INTEGERS
    //==================================================
    // DMA FSM
    localparam IDLE      = 3'd0,    // waiting for run bit
               PROC      = 3'd1,    // read data from mem then write to /read from fir AXI-ST
               WRITEBACK = 3'd2,    // write fir result back to mem, just do continuously 64T we
               IRQ       = 3'd3,    // pull up irq 1T
               POLL      = 3'd4;    // wait dma done read to clear
    // WB FSM
    localparam WB_IDLE  = 2'd0;
    localparam WB_READ  = 2'd1;

    // intergers
    integer i, j;

    //==================================================
    // INTERNAL REG & WIRES
    //==================================================
    // Configration Reg
    //--------------------------------------------------
    // #0x00
    // [0]: run bit, [1]: busy, [2]: done (only for poll mode, read2clear), [3]: irq(0),poll(1)
    reg [3:0]      dma_control;
    // #0x10
    reg [31:0]      dma_src;
    // #0x20
    reg [31:0]      dma_dst;
    // #0x30
    reg [7:0]       dma_len;        // support 1 ~ 255 times transfer
    //--------------------------------------------------
    // FSM
    reg [2:0]       cs, ns;
    reg             wb_cs, wb_ns;
    // Control Reg
    reg [7:0]       fir_in_count;
    reg [7:0]       fir_out_count;
    reg [7:0]       read_ack_count;
    reg [7:0]       mem_count;

    reg [31:0]      mem_addr_control;
    reg [31:0]      wb_data_o_reg;
    // Buffer
    reg [8159:0]      buf_mem2fir ;
    reg [8159:0]        buf_fir2mem ;

    //==================================================
    // FSM
    //==================================================
    // DMA
    always @(posedge clk) begin
        if (rst)
            cs <= IDLE;
        else
            cs <= ns;
    end
    always @(*) begin
        ns <= IDLE;
        case(cs)
            IDLE:       ns <= (dma_control[0])? PROC : IDLE;
            PROC:       ns <= (fir_out_count == dma_len)? WRITEBACK : PROC;
            WRITEBACK:  ns <= (~(mem_count == dma_len))? WRITEBACK : (dma_control[3]) ? POLL : IRQ;
            IRQ:        ns <= IDLE;
            POLL:       ns <= (~dma_control[2])? IDLE : POLL;
        endcase
    end

    // WB
    always @(posedge clk) begin
        if (rst)
            wb_cs <= WB_IDLE;
        else
            wb_cs <= wb_ns;
    end
    always @(*) begin
        wb_ns <= WB_IDLE;
        case(wb_cs)
            WB_IDLE:    wb_ns <= (wb_en & (~wb_we))? WB_READ : WB_IDLE;
            WB_READ:    wb_ns <= WB_IDLE;
        endcase
    end

    //==================================================
    // Configration Registers
    //==================================================
    // dma_control
    // run bit
    always @(posedge clk ) begin
        if (rst | ns == PROC)
            dma_control[0] <= 1'b0;
        else if (wb_addr == 12'h000 & wb_we & wb_en & cs == IDLE)
            dma_control[0] <= wb_data_i[0];
        else
            dma_control[0] <= dma_control[0];
    end
    // busy
    always @(posedge clk ) begin
        if (rst | ns == IDLE)
            dma_control[1] <= 1'b0;
        else
            dma_control[1] <= 1'b1;
    end
    // done
    always @(posedge clk ) begin
        if (rst)
            dma_control[2] <= 1'b0;
        else if (cs == WRITEBACK & ns == POLL)
            dma_control[2] <= 1'b1;
        else if (wb_addr == 12'h000 & wb_en & cs == POLL & wb_cs == WB_READ)
            dma_control[2] <= 1'b0;
        else
            dma_control[2] <= dma_control[2];
    end
    // IRQ/POLL
    always @(posedge clk ) begin
        if (rst)
            dma_control[3] <= 1'b0;
        else if (wb_addr == 12'h000 & wb_we & wb_en & cs == IDLE)
            dma_control[3] <= wb_data_i[3];
        else
            dma_control[3] <= dma_control[3];
    end

    // dma_src
    always @(posedge clk ) begin
        if (rst)
            dma_src <= 32'd0;
        else if (wb_addr == 12'h010 & wb_we & wb_en & cs == IDLE)
            dma_src <= wb_data_i;
        else
            dma_src <= dma_src;
    end

    // dma_dst
    always @(posedge clk ) begin
        if (rst)
            dma_dst <= 32'd0;
        else if (wb_addr == 12'h020 & wb_we & wb_en & cs == IDLE)
            dma_dst <= wb_data_i;
        else
            dma_dst <= dma_dst;
    end

    // dma_len
    always @(posedge clk ) begin
        if (rst)
            dma_len <= 8'd0;
        else if (wb_addr == 12'h030 & wb_we & wb_en & cs == IDLE)
            dma_len <= wb_data_i[7:0];
        else
            dma_len <= dma_len;
    end

    //==================================================
    // Control Registers
    //==================================================
    // fir_in_count (X)
    always @(posedge clk ) begin
        if (rst | (cs == IDLE))
            fir_in_count <= 8'd0;
        else if (ss_tready & ss_tvalid)
            fir_in_count <= fir_in_count + 1'b1;    // 最大會到dma_len (ex:0~64)
        else
            fir_in_count <= fir_in_count;
    end

    // fir_out_count (Y)
    always @(posedge clk ) begin
        if (rst | (cs == IDLE))
            fir_out_count <= 8'd0;
        else if (sm_tready & sm_tvalid)
            fir_out_count <= fir_out_count + 1'b1;    // 最大會到dma_len (ex:0~64)
        else
            fir_out_count <= fir_out_count;
    end

    // read_ack_count
    always @(posedge clk ) begin
        if (rst | (cs == IDLE))
            read_ack_count <= 8'd0;
        else if (dma_read_ack)
            read_ack_count <= read_ack_count + 1'b1;    // 最大會到dma_len (ex:0~64)
        else
            read_ack_count <= read_ack_count;
    end
    
    // mem_count (continuously send r/w to dma_mem until == dma_len)
    always @(posedge clk ) begin
        if (rst | ((cs == PROC) & (ns == WRITEBACK)) | (cs == IDLE))
            mem_count <= 8'd0;
        else if (((cs == PROC) & (mem_count < dma_len)) | ((cs == WRITEBACK) & (mem_count < dma_len)))  // ex: 0 ~ 64
            mem_count <= mem_count + 1'b1;
        else
            mem_count <= mem_count;
    end

    // buf_mem2fir [0:254]
    always @(posedge clk) begin
        if (rst) begin
           buf_mem2fir <= 0;
        end 
        else if (dma_read_ack) begin
            for(i=0; i<255; i=i+1) begin
                if(read_ack_count == i) begin
                    buf_mem2fir[32*(i+1)-1-:32] <= dma_data_o;
                end
            end
    end
end

    // buf_fir2mem [0:254]
    always @(posedge clk) begin
        if (rst) begin
            buf_fir2mem <= 0;
        end
        else if (sm_tready & sm_tvalid) begin
           for(i=0; i<255; i=i+1) begin
                if(fir_out_count == i) begin
                    buf_fir2mem[32*(i+1)-1-:32] <= sm_tdata;
                end
           end
        end
    end


    //==================================================
    // WB
    //==================================================
    assign wb_data_o = wb_data_o_reg;
    assign wb_ack = (wb_en & wb_we) | (wb_cs == WB_READ);
    // wb_data_o_reg
    always @(*) begin
        wb_data_o_reg <= dma_control;
        case(wb_addr)
        12'h000: wb_data_o_reg <= dma_control;
        12'h010: wb_data_o_reg <= dma_src;
        12'h020: wb_data_o_reg <= dma_dst;
        12'h030: wb_data_o_reg <= dma_len;
        default: wb_data_o_reg <= dma_control;
        endcase
    end

    //==================================================
    // AXI-ST master X (FIR IN)
    //==================================================

    assign ss_tdata  = buf_mem2fir[32*(fir_in_count+1)-1-:32]; //[31:0] buf_mem2fir[0:255]
    assign ss_tvalid = (cs == PROC) & (fir_in_count < dma_len) & (read_ack_count > 0);
    assign ss_tlast  = (fir_in_count == dma_len-1);

    //==================================================
    // AXI-ST slave Y (FIR OUT)
    //==================================================
    assign sm_tready = (cs == PROC) & (fir_out_count < dma_len);

    //==================================================
    // DMA MEM
    //==================================================
    assign dma_addr   = mem_addr_control;
    assign dma_data_i = buf_fir2mem[32*(mem_count+1)-1-:32];     // For WRITEBACK
    assign dma_we     = (cs == WRITEBACK) & (mem_count < dma_len);
    assign dma_en     = ((cs == PROC) & (mem_count < dma_len)) | ((cs == WRITEBACK) & (mem_count < dma_len));

    // mem_addr_control
    always @(posedge clk) begin
        if (rst)
            mem_addr_control <= 32'd0;
        else if ((cs == IDLE & ns == PROC) | (cs == PROC & ns == WRITEBACK))
            mem_addr_control <= dma_src;
        else if (cs == PROC | cs == WRITEBACK)
            mem_addr_control <= mem_addr_control + 32'd4;
        else
            mem_addr_control <= 32'd0;
    end

    //==================================================
    // IRQ
    //==================================================
    assign dma_irq = (cs == IRQ);

endmodule