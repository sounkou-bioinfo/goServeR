#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include "goserveR.h"

static const R_CallMethodDef CallEntries[] = {
    {"serve_start", (DL_FUNC) &serve_start, 1},
    {NULL, NULL, 0}
};

void R_init_goserveR(DL_FUNC dlsym) {
    R_registerRoutines(dlsym, NULL, CallEntries, NULL, NULL);
    R_useDynamicSymbols(dlsym, FALSE);
}
