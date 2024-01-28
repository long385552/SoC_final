/*
 * SPDX-FileCopyrightText: 2020 Efabless Corporation
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * SPDX-License-Identifier: Apache-2.0
 */

// This include is relative to $CARAVEL_PATH (see Makefile)
#include <defs.h>
#include <stub.c>
// #include <stdint.h>
// #include <stdbool.h>

extern int polling();
#ifdef USER_PROJ_IRQ0_EN
	#include <irq_vex.h>
#endif

// extern int* matmul();
// extern int* qsort();

#define reg_fir_control (*(volatile uint32_t*)0x30000000)


#include "fir.h"
//DMA mem offest
#define offest 0xFC
//fir control
#define reg_fir_control (*(volatile uint32_t*)0x30000000)
// data len 
#define reg_fir_len 	(*(volatile uint32_t*)0x30000010)
// TAP coeff
#define reg_fir_coeff0  (*(volatile uint32_t*)0x30000020)
#define reg_fir_coeff1  (*(volatile uint32_t*)0x30000024)
#define reg_fir_coeff2  (*(volatile uint32_t*)0x30000028)
#define reg_fir_coeff3  (*(volatile uint32_t*)0x3000002c)
#define reg_fir_coeff4  (*(volatile uint32_t*)0x30000030)
#define reg_fir_coeff5  (*(volatile uint32_t*)0x30000034)
#define reg_fir_coeff6  (*(volatile uint32_t*)0x30000038)
#define reg_fir_coeff7  (*(volatile uint32_t*)0x3000003c)
#define reg_fir_coeff8  (*(volatile uint32_t*)0x30000040)
#define reg_fir_coeff9  (*(volatile uint32_t*)0x30000044)
#define reg_fir_coeff10 (*(volatile uint32_t*)0x30000048)
//DMA
//#define dma_control     	(*(volatile uint32_t*)0x38600000) // start = bit[0], idle = bit[1], done = bit[2], irq(0)/poll(1) = bit[3]
#define dma_source_adr		(*(volatile uint32_t*)0x38600010) // 0x38500000
#define dma_destination_adr	(*(volatile uint32_t*)0x38600020) // 0x38600000
#define dma_data_len		(*(volatile uint32_t*)0x38600030) // 64
//DMA mem
int32_t x[64] = {
    0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 
    11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 
    21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 
    31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 
    41, 42, 43, 44, 45, 46, 47, 48, 49, 50, 
    51, 52, 53, 54, 55, 56, 57, 58, 59, 60, 
    61, 62, 63
};
#define dma_mem		(*(volatile uint32_t*)(0x38500000+offest)) //fir last lata
// --------------------------------------------------------

/*
	MPRJ Logic Analyzer Test:
		- Observes counter value through LA probes [31:0] 
		- Sets counter initial value through LA probes [63:32]
		- Flags when counter value exceeds 500 through the management SoC gpio
		- Outputs message to the UART when the test concludes successfuly
*/

void __attribute__ ( ( section ( ".mprjram" ) ) ) main()
{
#ifdef USER_PROJ_IRQ0_EN
    int mask;
#endif
	int j;
	// int outputsignal[N];
	/* Set up the housekeeping SPI to be connected internally so	*/
	/* that external pin changes don't affect it.			*/

	// reg_spi_enable = 1;
	// reg_spimaster_cs = 0x00000;

	// reg_spimaster_control = 0x0801;

	// reg_spimaster_control = 0xa002;	// Enable, prescaler = 2,
                                        // connect to housekeeping SPI

	// Connect the housekeeping SPI to the SPI master
	// so that the CSB line is not left floating.  This allows
	// all of the GPIO pins to be used for user functions.

	// The upper GPIO pins are configured to be output
	// and accessble to the management SoC.
	// Used to flad the start/end of a test 
	// The lower GPIO pins are configured to be output
	// and accessible to the user project.  They show
	// the project count value, although this test is
	// designed to read the project count through the
	// logic analyzer probes.
	// I/O 6 is configured for the UART Tx line

        reg_mprj_io_31 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_30 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_29 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_28 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_27 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_26 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_25 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_24 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_23 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_22 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_21 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_20 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_19 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_18 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_17 = GPIO_MODE_MGMT_STD_OUTPUT;
        reg_mprj_io_16 = GPIO_MODE_MGMT_STD_OUTPUT;

        reg_mprj_io_15 = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_14 = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_13 = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_12 = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_11 = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_10 = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_9  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_8  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_7  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_5  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_4  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_3  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_2  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_1  = GPIO_MODE_USER_STD_OUTPUT;
        reg_mprj_io_0  = GPIO_MODE_USER_STD_OUTPUT;

        reg_mprj_io_6  = GPIO_MODE_MGMT_STD_OUTPUT;

	// Set UART clock to 64 kbaud (enable before I/O configuration)
	// reg_uart_clkdiv = 625;
	// reg_uart_enable = 1;
	
	// Now, apply the configuration
	reg_mprj_xfer = 1;
	while (reg_mprj_xfer == 1);

        // Configure LA probes [31:0], [127:64] as inputs to the cpu 
	// Configure LA probes [63:32] as outputs from the cpu
	reg_la0_oenb = reg_la0_iena = 0x00000000;    // [31:0]
	reg_la1_oenb = reg_la1_iena = 0xFFFFFFFF;    // [63:32]
	reg_la2_oenb = reg_la2_iena = 0x00000000;    // [95:64]
	reg_la3_oenb = reg_la3_iena = 0x00000000;    // [127:96]

	// Flag start of the test 
	// Set Counter value to zero through LA probes [63:32]
	reg_la1_data = 0x00000000;

	// Configure LA probes from [63:32] as inputs to disable counter write
	reg_la1_oenb = reg_la1_iena = 0x00000000;

	//FIR configuration
	reg_fir_len = 64;
	reg_fir_coeff0 	= 0;
	reg_fir_coeff1 	= -10;
	reg_fir_coeff2 	= -9;
	reg_fir_coeff3 	= 23;
	reg_fir_coeff4 	= 56;
	reg_fir_coeff5 	= 63;
	reg_fir_coeff6 	= 56;
	reg_fir_coeff7 	= 23;
	reg_fir_coeff8 	= -9;
	reg_fir_coeff9 	= -10;
	reg_fir_coeff10 = 0;

/*
	while (1) {
		if (reg_la0_data_in > 0x1F4) {
			reg_mprj_datal = 0xAB410000;
			break;
		}
	}
*/	
#ifdef USER_PROJ_IRQ0_EN	
	// unmask USER_IRQ_0_INTERRUPT
	mask = irq_getmask();
	mask |= 1 << USER_IRQ_0_INTERRUPT; // USER_IRQ_0_INTERRUPT = 2
	irq_setmask(mask);
	// enable user_irq_0_ev_enable
	user_irq_0_ev_enable_write(1);	
#endif


	int32_t *addr_x = x; //0x38500000
	//DMA engine configuration
	dma_data_len = 64;
	dma_source_adr = 0x38500000;
	dma_destination_adr = 0x38600000;
	reg_fir_control = 1;
	dma_control = 0x00000009;
	
	reg_mprj_datal = 0x00A50000;

	// int* tmp1 = matmul();
	// int* tmp2 = qsort();

	//polling
	/*
	while(((dma_control >> 2) & 1) != 1); 
    uint32_t data = dma_mem;
	*/
	int tmp = polling();
	reg_mprj_datal = (tmp << 24) | (0x5A << 16);

	
	//reg_mprj_datal = (*tmp << 24) | (0x5A << 16); //mprj[31:0] = {fianl Y, EndMark, 16'h0000} 
	//}
	//print("\n");
	//print("Monitor: Test 1 Passed\n\n");	// Makes simulation very long!
}

