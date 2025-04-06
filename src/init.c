#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <stdlib.h>
#include "Rserve.h"

// Make sure the declaration matches the implementation
SEXP run_server(SEXP, SEXP, SEXP);

// Register the native routine
static const R_CallMethodDef CallEntries[] = {
    {"run_server", (DL_FUNC) &run_server, 3},
    {NULL, NULL, 0}
};

void R_init_goserveR(DllInfo *dll) {
    R_registerRoutines(
                dll,
                NULL,
                CallEntries,
                NULL,
                NULL
                );
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE);  // Ensure all symbols are found through the registration table
}
