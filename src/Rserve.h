
#ifndef _GOSERVER_RSERVE_H_
#define _GOSERVER_RSERVE_H_

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Visibility.h>
#include "serve.h"

// ref : https://github.com/cran/curl/blob/master/src/interrupt.c
// https://stackoverflow.com/questions/40563522/r-how-to-write-interruptible-c-function-and-recover-partial-results

void check_interrupt_fn(void *dummy) {
  R_CheckUserInterrupt();
}
//
int pending_interrupt(void) {
  return !(R_ToplevelExec(check_interrupt_fn, NULL));
}

typedef int (*R_interupt_fun) (void); 

int interupter( R_interupt_fun f) {
  return f();
}
//go  function, this is also available in serve.h
extern void RunServer(char* dir, char* addr, char* prefix, 
   R_interupt_fn pending_interupt_checher );



#endif
