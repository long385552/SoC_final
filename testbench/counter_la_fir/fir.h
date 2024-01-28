
#define __FIR_H__
#include <stdint.h>
#include <stdbool.h>

// #define N 64
#define dma_control     	(*(volatile uint32_t*)0x38600000) // start = bit[0], idle = bit[1], done = bit[2], irq(0)/poll(1) = bit[3]
// int outputsignal[N];
// // AP control
// #define reg_fir_control (*(volatile uint32_t*)0x30000000)
// // FIR input X, FIR output Y
// #define reg_fir_x (*(volatile uint32_t*)0x30000080)
// #define reg_fir_y (*(volatile uint32_t*)0x30000084)
// #endif
