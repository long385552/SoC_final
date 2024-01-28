// SPDX-FileCopyrightText: 2020 Efabless Corporation
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// SPDX-License-Identifier: Apache-2.0

`default_nettype wire
/*
 *-------------------------------------------------------------
 *
 * user_proj_example
 *
 * This is an example of a (trivially simple) user project,
 * showing how the user project can connect to the logic
 * analyzer, the wishbone bus, and the I/O pads.
 *
 * This project generates an integer count, which is output
 * on the user area GPIO pads (digital output only).  The
 * wishbone connection allows the project to be controlled
 * (start and stop) from the management SoC program.
 *
 * See the testbenches in directory "mprj_counter" for the
 * example programs that drive this user project.  The three
 * testbenches are "io_ports", "la_test1", and "la_test2".
 *
 *-------------------------------------------------------------
 */

module user_proj_example #(
    parameter BITS = 32,
    parameter DELAYS=10
)
(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif
    // Global
    //--------------------------------------------------
    input                      wb_clk_i,
    input                      wb_rst_i,
    // Wishbone Slave ports (WB MI A)
    //--------------------------------------------------
    input                      wbs_stb_i,
    input                      wbs_cyc_i,
    input                      wbs_we_i,
    input   [3:0]              wbs_sel_i,
    input  [31:0]              wbs_dat_i,
    input  [31:0]              wbs_adr_i,
    output                     wbs_ack_o,
    output [31:0]              wbs_dat_o,
    // Logic Analyzer Signals
    //--------------------------------------------------
    input  [127:0]             la_data_in,
    output [127:0]             la_data_out,
    input  [127:0]             la_oenb,
    // IOs
    //--------------------------------------------------
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,
    // IRQ
    //--------------------------------------------------
    output [2:0] irq
);
    //================================================================
    // INTERNAL WIRES / REGS
    //================================================================
    // wb addr decoded
    wire wb2bram;
    wire wb2fir;  
    wire wb2dma; 
    wire wb2dma_mem;
    // user bram
    wire [31:0] ram_o; 
    wire [31:0] wdata;
    wire en;
    wire bram_we;
    wire bram_en;
    //wire wbs_ack_o;
    wire [`MPRJ_IO_PADS-1:0] io_in;
    wire [`MPRJ_IO_PADS-1:0] io_out;
    wire [`MPRJ_IO_PADS-1:0] io_oeb;
    wire clk;
    wire rst, rst_n;
    reg [3:0] counter;
    // fir (wb2axi)
    wire fir_en;
    wire fir_we;
    wire fir_valid;
    wire [31:0] fir_o;
    // dma
    wire dma_en;
    wire dma_we;
    wire dma_ack;
    wire [31:0] dma_o;
    // dma mem
    wire dma_mem_en;
    wire [3:0] dma_mem_we;
    wire dma_mem_ack;
    wire [31:0]dma_mem_o;

    wire [31:0] dma_addr;
    wire [31:0] dma_data_i;
    wire [31:0] dma_data_o;
    wire        dma2mem_we;
    wire        dma2mem_en;
    wire        dma_read_ack;
    // sdram
    wire sdram_cle;
    wire sdram_cs;
    wire sdram_cas;
    wire sdram_ras;
    wire sdram_we;
    wire sdram_dqm;
    wire [1:0] sdram_ba;
    wire [12:0] sdram_a;
    wire [31:0] d2c_data;
    wire [31:0] c2d_data;
    wire [3:0]  bram_mask;

    wire [22:0] ctrl_addr;
    wire ctrl_busy;
    wire ctrl_in_valid, ctrl_out_valid;

    reg ctrl_in_valid_q;
    // sdram prefetch
    reg [22:0] next_addr;
	reg next_in;
	reg [22:0] last_in_addr;
	wire [22:0] user_addr;
	wire [22:0] diff;
    //--------------------------------------------------
    // AXI-ST master - X
    wire                     ss_tready;
    wire                     ss_tvalid;
    wire                     ss_tlast;
    wire [31:0]              ss_tdata;
    //--------------------------------------------------
    // AXI-ST slave - Y
    wire                     sm_tready;
    wire                     sm_tvalid;
    wire                     sm_tlast;
    wire [31:0]              sm_tdata;

    //================================================================
    // INSTANCES
    //================================================================
    // firmware bram (sdram)
    sdram_controller user_sdram_controller (
        .clk(clk),
        .rst(rst),
        
        .sdram_cle(sdram_cle),
        .sdram_cs(sdram_cs),
        .sdram_cas(sdram_cas),
        .sdram_ras(sdram_ras),
        .sdram_we(sdram_we),
        .sdram_dqm(sdram_dqm),
        .sdram_ba(sdram_ba),
        .sdram_a(sdram_a),
        .sdram_dqi(d2c_data),
        .sdram_dqo(c2d_data),

        .user_addr(user_addr),
        .rw(bram_we),
        .data_in(wdata),
        .data_out(ram_o),
        .busy(ctrl_busy),
        .in_valid(ctrl_in_valid),
        .out_valid(ctrl_out_valid)
    );

    sdr user_bram (
        .Rst_n(rst_n),
        .Clk(clk),
        .Cke(sdram_cle),
        .Cs_n(sdram_cs),
        .Ras_n(sdram_ras),
        .Cas_n(sdram_cas),
        .We_n(sdram_we),
        .Addr(sdram_a),
        .Ba(sdram_ba),
        .Dqm(bram_mask),
        .Dqi(c2d_data),
        .Dqo(d2c_data)
    );
    // wb2axi
    wb2axi user_wb2axi (
        // Global
        .clk(clk),
        .rst(rst),
        // WB decoded
        .fir_en(fir_en),
        .fir_we(fir_we),
        .fir_addr(wbs_adr_i[11:0]),
        .fir_dat_i(wdata),
        .fir_valid(fir_valid),
        .fir_dat_o(fir_o),
        // AXI-ST master - X
        .ss_tready(ss_tready),
        .ss_tvalid(ss_tvalid), 
        .ss_tlast(ss_tlast),
        .ss_tdata(ss_tdata),
        // AXI-ST slave - Y
        .sm_tready(sm_tready), 
        .sm_tvalid(sm_tvalid),  
        .sm_tlast(sm_tlast), 
        .sm_tdata(sm_tdata)
    );

    dma_engine dma0
    (   
    // Global
    .clk(clk),
    .rst(rst),
    // Wishbone
    .wb_addr(wbs_adr_i[11:0]),
    .wb_data_i(wdata),
    .wb_we(dma_we),
    .wb_en(dma_en),
    .wb_data_o(dma_o),
    .wb_ack(dma_ack),
    // AXI-ST master - X
    .ss_tready(ss_tready),
    .ss_tvalid(ss_tvalid), 
    .ss_tlast(ss_tlast),
    .ss_tdata(ss_tdata),
    // AXI-ST slave - Y
    .sm_tready(sm_tready), 
    .sm_tvalid(sm_tvalid),  
    .sm_tlast(sm_tlast), 
    .sm_tdata(sm_tdata),
    // DMA MEM
    .dma_addr(dma_addr),
    .dma_data_i(dma_data_i),
    .dma_we(dma2mem_we),
    .dma_en(dma2mem_en),    // dma_en high 1T for 1 data
    .dma_data_o(dma_data_o),
    .dma_read_ack(dma_read_ack),
    // DMA IRQ
    .dma_irq(irq[0])
    );

    dma_mem dma_mem0
    (   
    // Global
    .clk(clk),
    .rst(rst),
    // Wishbone
    .wb_addr(wbs_adr_i),
    .wb_data_i(wdata),
    .wb_we(dma_mem_we),//0x385
    .wb_en(dma_mem_en),//
    .wb_data_o(dma_mem_o),
    .wb_ack(dma_mem_ack),
    // DMA (always ready for DMA access)
    .dma_addr(dma_addr),
    .dma_data_i(dma_data_i),
    .dma_we(dma2mem_we),//0x386
    .dma_en(dma2mem_en),//x0386
    .dma_data_o(dma_data_o),
    .dma_read_ack(dma_read_ack)
    );

    //================================================================
    // WB MI A
    //================================================================
    // WB input control
    assign en    = wbs_cyc_i & wbs_stb_i; 
    assign wdata = wbs_dat_i;
    // WB output control
    assign wbs_ack_o = ((wbs_we_i & wb2bram) ? ~ctrl_busy && en : ctrl_out_valid && en && (diff==4)) 
                       | (fir_valid) | (dma_ack) | (dma_mem_ack);
    assign wbs_dat_o = ({32{wb2bram}} & ram_o) | ({32{wb2fir}} & fir_o) | ({32{wb2dma}} & dma_o) | ({32{wb2dma_mem}} & dma_mem_o);
    // WB addr decode
    assign wb2bram     = (wbs_adr_i[31:20] == 12'h380);
    assign wb2fir      = (wbs_adr_i[31:24] == 8'h30);
    assign wb2dma      = (wbs_adr_i[31:20] == 12'h386);  
    assign wb2dma_mem  = (wbs_adr_i[31:20] == 12'h385);  
    // sdram control
    assign ctrl_in_valid = (wbs_we_i && wb2bram) ? en : (~ctrl_in_valid_q && en && !ctrl_busy);
    assign ctrl_addr = wbs_adr_i[22:0];
    assign bram_mask = wbs_sel_i & {4{wbs_we_i}};
    //================================================================
    // WB decoded to user_bram (sdram)
    //================================================================
    always @(posedge clk) begin
        if (rst) begin
            ctrl_in_valid_q <= 1'b0;
        end
        else begin
            if (~wbs_we_i && en && ~ctrl_busy && ctrl_in_valid_q == 1'b0)
                ctrl_in_valid_q <= 1'b1;
            else if (ctrl_out_valid || ~ctrl_busy)
                ctrl_in_valid_q <= 1'b0;
        end
    end
    //================================================================
    // Sdram prefech
    //================================================================
	//assign diff = user_addr-last_in_addr;
	assign diff = last_in_addr - ctrl_addr;
	assign user_addr = (next_in && en && !wbs_we_i ) ? next_addr : ctrl_addr;

	always@(posedge clk)begin
		if(rst)
			next_addr <= 0;
		else
			next_addr <= (ctrl_in_valid && !wbs_we_i) ? user_addr + 4 : next_addr;
	end

	always@(posedge clk)begin
		if(rst)
			next_in <= 0;
		else begin
			if(en && !wbs_we_i)
				next_in <= (ctrl_in_valid_q) ? 1 : next_in;
			else
				next_in <= 0;
		end
	end
	
	always@(posedge clk)begin
		if(rst)
			last_in_addr <= 0;
		else begin
			last_in_addr <= (en && ctrl_in_valid) ? user_addr : last_in_addr;
		end
	end
    // firmware bram (sdram) control
    assign bram_we = wbs_we_i & wb2bram;
    assign bram_en = en & wb2bram;

    //================================================================
    // WB decoded to fir
    //================================================================
    assign fir_en = en & wb2fir;
    assign fir_we = wbs_we_i & wb2fir;

    //================================================================
    //  WB decoded to dma
    //================================================================
    assign dma_en = en && wb2dma;
    assign dma_we = wbs_we_i & wb2dma;//0x38600000

    //================================================================
    //  WB decoded to dma_mem
    //================================================================
    assign dma_mem_en = en & wb2dma_mem;
    assign dma_mem_we = wbs_sel_i & { 4{wbs_we_i} } & { 4{wbs_cyc_i} } & { 4{wb2dma_mem} };

    //================================================================
    // IO (Unused)
    //================================================================
    assign io_out = d2c_data;
    assign io_oeb = {(`MPRJ_IO_PADS-1){rst}};

    //================================================================
    // IRQ 
    //================================================================
    assign irq[2:1] = 2'd0;

    //================================================================
    // LA (Unused)
    //================================================================
    assign la_data_out = {{(124){1'b0}}, d2c_data};	
    // Assuming LA probes [65:64] are for controlling the seq_gcd clk & reset  
    assign clk = (~la_oenb[64]) ? la_data_in[64] : wb_clk_i;
    assign rst = (~la_oenb[65]) ? la_data_in[65] : wb_rst_i;
    assign rst_n = ~rst;

endmodule
