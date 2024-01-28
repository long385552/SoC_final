#include "fir.h"
#define offest 0xFC
#define dma_mem		(*(volatile uint32_t*)(0x38500000+0xFC)) //fir last lata

int __attribute__ ( ( section ( ".mprjram" ) ) ) polling(){ 

	while(((dma_control >> 2) & 1) != 1); 
    uint32_t data = dma_mem;

	return data;
}
		
