/*
 * WebAssembly compatibility shim.
 *
 * Browser-hosted R runtimes cannot bind listening sockets, and Go's cgo
 * shared-library build mode does not target webR. These entry points keep the
 * package installable and loadable while reporting the unsupported operation
 * clearly when server functionality is requested.
 */

#include <R.h>
#include <Rinternals.h>

static void wasm_server_error(void)
{
    Rf_error("goserveR cannot start HTTP servers in a WebAssembly runtime");
}

SEXP run_server(SEXP r_dir, SEXP r_addr, SEXP r_prefix, SEXP r_blocking,
                SEXP r_cors, SEXP r_coop, SEXP r_tls, SEXP r_certfile,
                SEXP r_keyfile, SEXP r_silent, SEXP r_log_handler,
                SEXP r_auth_keys)
{
    (void) r_dir;
    (void) r_addr;
    (void) r_prefix;
    (void) r_blocking;
    (void) r_cors;
    (void) r_coop;
    (void) r_tls;
    (void) r_certfile;
    (void) r_keyfile;
    (void) r_silent;
    (void) r_log_handler;
    (void) r_auth_keys;
    wasm_server_error();
    return R_NilValue;
}

SEXP list_servers(void)
{
    return Rf_allocVector(VECSXP, 0);
}

SEXP shutdown_server(SEXP extptr)
{
    (void) extptr;
    return R_NilValue;
}

SEXP is_running(SEXP extptr)
{
    (void) extptr;
    return Rf_ScalarLogical(0);
}

SEXP register_log_handler(SEXP s_fd, SEXP callback, SEXP user)
{
    (void) s_fd;
    (void) callback;
    (void) user;
    wasm_server_error();
    return R_NilValue;
}

SEXP remove_log_handler(SEXP h_ptr)
{
    (void) h_ptr;
    return Rf_ScalarLogical(0);
}

SEXP manage_server_auth(SEXP server_handle, SEXP key, SEXP action)
{
    (void) server_handle;
    (void) key;
    (void) action;
    wasm_server_error();
    return R_NilValue;
}

SEXP list_server_auth_keys(SEXP server_handle)
{
    (void) server_handle;
    return Rf_allocVector(STRSXP, 0);
}

SEXP add_initial_server_auth_keys(SEXP server_handle, SEXP keys)
{
    (void) server_handle;
    (void) keys;
    wasm_server_error();
    return R_NilValue;
}
