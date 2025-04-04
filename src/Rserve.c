#include <R.h>
#include <Rinternals.h>
#include <stdlib.h>
#include <stdio.h>
#include "Rserve.h"
#include "interupt.h"

// Declare the RunServer function from the shared library

SEXP run_server(SEXP r_dir, SEXP r_addr, SEXP r_prefix) {
    // Convert R character vectors to C strings
    const char* dir = CHAR(STRING_ELT(r_dir, 0));
    const char* addr = CHAR(STRING_ELT(r_addr, 0));
    const char* prefix = CHAR(STRING_ELT(r_prefix, 0));
    
    // Call the RunServer function
    // The Go code now handles interrupts
    RunServer((char*)dir, (char*)addr, (char*)prefix);

    return R_NilValue; // Return NULL to R
}

