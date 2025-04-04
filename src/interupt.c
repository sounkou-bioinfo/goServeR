#include "interupt.h"
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Visibility.h>

// Make this static so it's only visible in this file
static void check_interrupt_fn(void *dummy) {
  R_CheckUserInterrupt();
}

// Implement the pending_interrupt function
int pending_interrupt(void) {
  return !(R_ToplevelExec(check_interrupt_fn, NULL));
}
