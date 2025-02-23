
#ifndef _GOSERVER_RSERVE_H_
#define _GOSERVER_RSERVE_H_

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Visibility.h>
#include "serve.h"

//go  function
extern void RunServer(char* dir, char* addr, char* prefix);

//interupt 
// ref : https://github.com/cran/curl/blob/master/src/interrupt.c
// https://stackoverflow.com/questions/40563522/r-how-to-write-interruptible-c-function-and-recover-partial-results
/*
void check_interrupt_fn(void *dummy) {
  R_CheckUserInterrupt();
}

int pending_interrupt() {
  return !(R_ToplevelExec(check_interrupt_fn, NULL));
}
*/
#endif
