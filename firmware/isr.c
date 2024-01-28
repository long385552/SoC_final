// This file is Copyright (c) 2020 Florent Kermarrec <florent@enjoy-digital.fr>
// License: BSD
#include <csr.h>
#include <soc.h>
#include <irq_vex.h>
// #include <user_uart.h>
#include <defs.h>

//extern int fir();
// extern int uart_read();
// extern char uart_read_char();
// extern char uart_write_char();
// extern int uart_write();

void isr(void);

#ifdef CONFIG_CPU_HAS_INTERRUPT

#ifdef USER_PROJ_IRQ0_EN
uint32_t counter = 0xFFFF0000;
#endif

void isr(void)
{

#ifndef USER_PROJ_IRQ0_EN

    irq_setmask(0);


#else
    uint32_t irqs = irq_pending() & irq_getmask();
    int buf;

    if ( irqs & (1 << USER_IRQ_0_INTERRUPT)) {
        user_irq_0_ev_pending_write(1); //Clear Interrupt Pending Event
        // fir();
        // buf = uart_read();
        // uart_write(buf);

    }
#endif

    return;

}

#else

void isr(void){};

#endif

/*
#include <csr.h>
#include <soc.h>
#include <irq_vex.h>
#include <uart.h>
#include <defs.h>

void isr(void);

#ifdef CONFIG_CPU_HAS_INTERRUPT

uint16_t flag;

void isr(void)
{
//	__attribute__((unused)) unsigned int irqs;
//
//	irqs = irq_pending() & irq_getmask();
//
	irq_setmask(0);
//
//    reg_timer0_irq_en = 0; // disable interrupt
//    reg_debug_irq_en = 0;

//    reg_reset = 1;
//    asm volatile ("slli x0, x0, 0x1f");
//    asm volatile ("ebreak");
//    asm volatile ("srai x0, x0, 7");

   reg_la1_data = 0xa;
   reg_la0_data = 0x20000;
   flag = 1;

//	if(irqs & (1 << TIMER0_INTERRUPT)) {
////		uart_isr();
//        reg_la1_data = 0xa;	// Signal end of test 1st stage
//        reg_la0_data = 0x20000;
//        flag = 1;
//    }
    return;

//#ifndef UART_POLLING
//	if(irqs & (1 << UART_INTERRUPT))
//		uart_isr();
//#endif
}

#else

void isr(void){};

#endif
*/