#include <R.h>
#include <Rinternals.h>
#include <stdlib.h>
#include <stdio.h>
#include "Rserve.h"
#include "interupt.h"

// Make sure this matches the declaration in Rserve.h and init.c
SEXP run_server(SEXP r_dir, SEXP r_addr, SEXP r_prefix) {
    // Check that inputs are character vectors of length 1
    if (TYPEOF(r_dir) != STRSXP || LENGTH(r_dir) != 1 ||
        TYPEOF(r_addr) != STRSXP || LENGTH(r_addr) != 1 ||
        TYPEOF(r_prefix) != STRSXP || LENGTH(r_prefix) != 1) {
        error("Arguments must be character strings");
    }
    
    // Convert R character vectors to C strings
    const char* dir = CHAR(STRING_ELT(r_dir, 0));
    const char* addr = CHAR(STRING_ELT(r_addr, 0));
    const char* prefix = CHAR(STRING_ELT(r_prefix, 0));
    
    // Print debug info
    Rprintf("Starting server with: dir=%s, addr=%s, prefix=%s\n", dir, addr, prefix);
    
    // Call the RunServer function from Go
    RunServer((char*)dir, (char*)addr, (char*)prefix);

    return R_NilValue; // Return NULL to R
}

