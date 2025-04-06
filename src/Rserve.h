#ifndef _GOSERVER_RSERVE_H_
#define _GOSERVER_RSERVE_H_

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Visibility.h>
#include "serve.h"
#include "interupt.h"

// Go function, this is also available in serve.h
// The declaration should match the one in serve.h
extern void RunServer(char* dir, char* addr, char* prefix);

// Declare the interface function with proper return type
SEXP run_server(SEXP r_dir, SEXP r_addr, SEXP r_prefix);

#endif
