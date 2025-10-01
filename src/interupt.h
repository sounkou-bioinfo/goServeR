#ifndef _GOSERVER_INTERUPT_H_
#define _GOSERVER_INTERUPT_H_
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Visibility.h>
#include <R_ext/Utils.h>
// ref : https://github.com/cran/curl/blob/master/src/interrupt.c
// https://stackoverflow.com/questions/40563522/r-how-to-write-interruptible-c-function-and-recover-partial-results

// These functions are defined in R_ext/Utils.h
void R_CheckUserInterrupt(void);
Rboolean R_ToplevelExec(void (*fun)(void *), void *data);

// Only declare the function, implementation is in interupt.c
int pending_interrupt(void);

#endif
