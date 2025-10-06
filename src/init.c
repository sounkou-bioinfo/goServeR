#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Boolean.h>
#include <stdlib.h>
#include "Rserve.h"
#include <signal.h>

// Make sure the declaration matches the implementation
SEXP run_server(SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP, SEXP);
SEXP list_servers();
SEXP shutdown_server(SEXP);
SEXP register_log_handler(SEXP, SEXP, SEXP);
SEXP remove_log_handler(SEXP);

// Auth management functions (new server-based)
SEXP manage_server_auth(SEXP, SEXP, SEXP);
SEXP list_server_auth_keys(SEXP);
SEXP add_initial_server_auth_keys(SEXP, SEXP);

// RC-level (raw C) entry points
SEXP RC_StartServer(SEXP r_dir, SEXP r_addr, SEXP r_prefix, SEXP r_blocking, SEXP r_cors, SEXP r_coop, SEXP r_tls, SEXP r_certfile, SEXP r_keyfile, SEXP r_silent, SEXP r_log_handler, SEXP r_auth_keys) {
    return run_server(r_dir, r_addr, r_prefix, r_blocking, r_cors, r_coop, r_tls, r_certfile, r_keyfile, r_silent, r_log_handler, r_auth_keys);
}
SEXP RC_ListServers() {
    return list_servers();
}
SEXP RC_ShutdownServer(SEXP extptr) {
    return shutdown_server(extptr);
}

// Register the native routines
static const R_CallMethodDef CallEntries[] = {
    {"RC_list_servers", (DL_FUNC) &list_servers, 0},
    {"RC_shutdown_server", (DL_FUNC) &shutdown_server, 1},
    {"RC_StartServer", (DL_FUNC) &RC_StartServer, 12},
    {"RC_ListServers", (DL_FUNC) &RC_ListServers, 0},
    {"RC_ShutdownServer", (DL_FUNC) &RC_ShutdownServer, 1},
    {"RC_register_log_handler", (DL_FUNC) &register_log_handler, 3},
    {"RC_remove_log_handler", (DL_FUNC) &remove_log_handler, 1},
    {"RC_manage_server_auth", (DL_FUNC) &manage_server_auth, 3},
    {"RC_list_server_auth_keys", (DL_FUNC) &list_server_auth_keys, 1},
    {"RC_add_initial_server_auth_keys", (DL_FUNC) &add_initial_server_auth_keys, 2},
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
