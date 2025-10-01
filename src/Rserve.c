#include <R.h>
#include <Rinternals.h>
#include <stdlib.h>
#include <stdio.h>
#include "Rserve.h"
#include "interupt.h"

#ifdef _WIN32
#include <windows.h>
#include <io.h>
#include <fcntl.h>
#define THREAD_TYPE HANDLE
#define THREAD_CREATE(thr, fn, arg) (*(thr) = CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)(fn), (arg), 0, NULL)) != NULL ? 0 : 1
#define THREAD_JOIN(thr) WaitForSingleObject((thr), INFINITE); CloseHandle(thr)
#define SLEEP_MS(ms) Sleep(ms)
#define PIPE_TYPE int
#define PIPE_CREATE(p) _pipe(p, 512, _O_BINARY)
#define PIPE_WRITE(p, buf, n) do { int _wr = _write((p)[1], (buf), (n)); if (_wr < 0) {} } while(0)
#define PIPE_CLOSE(p) { _close((p)[0]); _close((p)[1]); }
#else
#include <pthread.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/uio.h>
#define THREAD_TYPE pthread_t
#define THREAD_CREATE(thr, fn, arg) pthread_create((thr), NULL, (fn), (arg))
#define THREAD_JOIN(thr) pthread_join((thr), NULL)
#define SLEEP_MS(ms) usleep((ms)*1000)
#define PIPE_TYPE int
#define PIPE_CREATE(p) pipe(p)
#define PIPE_WRITE(p, buf, n) do { ssize_t _wr = write((p)[1], (buf), (n)); if (_wr < 0) {} } while(0)
#define PIPE_CLOSE(p) { close((p)[0]); close((p)[1]); }
#endif

// Global list of running servers 
#define MAX_SERVERS 16
static go_server_t* server_list[MAX_SERVERS] = {NULL};
static int server_count = 0;

// Helper: add/remove/list servers
static int add_server(go_server_t* srv) {
    for (int i = 0; i < MAX_SERVERS; ++i) {
        if (server_list[i] == NULL) {
            server_list[i] = srv;
            server_count++;
            return i;
        }
    }
    return -1;
}
static void remove_server(go_server_t* srv) {
    for (int i = 0; i < MAX_SERVERS; ++i) {
        if (server_list[i] == srv) {
            server_list[i] = NULL;
            server_count--;
            return;
        }
    }
}

// Thread entry for background server
static void* server_thread_fn(void* arg) {
    go_server_t* srv = (go_server_t*)arg;
    RunServerWithShutdown(srv->dir, srv->addr, srv->prefix, srv->cors, srv->coop, srv->tls, srv->silent, srv->certfile, srv->keyfile, srv->shutdown_pipe[0]);
    srv->running = 0;
    return NULL;
}

SEXP run_server(SEXP r_dir, SEXP r_addr, SEXP r_prefix, SEXP r_blocking, SEXP r_cors, SEXP r_coop, SEXP r_tls, SEXP r_certfile, SEXP r_keyfile, SEXP r_silent) {
    // Check that inputs are character vectors of length 1
    if (TYPEOF(r_dir) != STRSXP || LENGTH(r_dir) != 1 ||
        TYPEOF(r_addr) != STRSXP || LENGTH(r_addr) != 1 ||
        TYPEOF(r_prefix) != STRSXP || LENGTH(r_prefix) != 1 ||
        TYPEOF(r_blocking) != LGLSXP || LENGTH(r_blocking) != 1 ||
        TYPEOF(r_cors) != LGLSXP || LENGTH(r_cors) != 1 ||
        TYPEOF(r_coop) != LGLSXP || LENGTH(r_coop) != 1 ||
        TYPEOF(r_tls) != LGLSXP || LENGTH(r_tls) != 1 ||
        TYPEOF(r_certfile) != STRSXP || LENGTH(r_certfile) != 1 ||
        TYPEOF(r_keyfile) != STRSXP || LENGTH(r_keyfile) != 1 ||
        TYPEOF(r_silent) != LGLSXP || LENGTH(r_silent) != 1) {
        error("Arguments must be correct types");
    }
    const char* dir = CHAR(STRING_ELT(r_dir, 0));
    const char* addr = CHAR(STRING_ELT(r_addr, 0));
    const char* prefix = CHAR(STRING_ELT(r_prefix, 0));
    int blocking = LOGICAL(r_blocking)[0];
    int cors = LOGICAL(r_cors)[0];
    int coop = LOGICAL(r_coop)[0];
    int tls = LOGICAL(r_tls)[0];
    const char* certfile = CHAR(STRING_ELT(r_certfile, 0));
    const char* keyfile = CHAR(STRING_ELT(r_keyfile, 0));
    int silent = LOGICAL(r_silent)[0];
    PIPE_TYPE shutdown_pipe[2];
    if (PIPE_CREATE(shutdown_pipe) != 0) {
        error("Failed to create shutdown pipe");
    }
    if (blocking) {
        go_server_t* srv = (go_server_t*)calloc(1, sizeof(go_server_t));
        srv->dir = strdup(dir);
        srv->addr = strdup(addr);
        srv->prefix = strdup(prefix);
        srv->cors = cors;
        srv->coop = coop;
        srv->tls = tls;
        srv->certfile = strdup(certfile);
        srv->keyfile = strdup(keyfile);
        srv->silent = silent;
        srv->running = 1;
        srv->shutdown_pipe[0] = shutdown_pipe[0];
        srv->shutdown_pipe[1] = shutdown_pipe[1];
        if (THREAD_CREATE(&srv->thread, server_thread_fn, srv) != 0) {
            PIPE_CLOSE(shutdown_pipe);
            free(srv->dir); free(srv->addr); free(srv->prefix); free(srv->certfile); free(srv->keyfile); free(srv);
            error("Failed to start server thread");
        }
        Rprintf("Server started in blocking mode. Press Ctrl+C to interrupt.\n");
        add_server(srv);
        while (srv->running) {
            if (pending_interrupt()) {
                PIPE_WRITE(shutdown_pipe, "x", 1);
                break;
            }
            SLEEP_MS(200);
        }
        THREAD_JOIN(srv->thread);
        srv->running = 0;
        remove_server(srv);
        PIPE_CLOSE(shutdown_pipe);
        free(srv->dir); free(srv->addr); free(srv->prefix); free(srv->certfile); free(srv->keyfile); free(srv);
        return R_NilValue;
    } else {
        go_server_t* srv = (go_server_t*)calloc(1, sizeof(go_server_t));
        srv->dir = strdup(dir);
        srv->addr = strdup(addr);
        srv->prefix = strdup(prefix);
        srv->cors = cors;
        srv->coop = coop;
        srv->tls = tls;
        srv->certfile = strdup(certfile);
        srv->keyfile = strdup(keyfile);
        srv->silent = silent;
        srv->running = 1;
        srv->shutdown_pipe[0] = shutdown_pipe[0];
        srv->shutdown_pipe[1] = shutdown_pipe[1];
        if (THREAD_CREATE(&srv->thread, server_thread_fn, srv) != 0) {
            PIPE_CLOSE(shutdown_pipe);
            free(srv->dir); free(srv->addr); free(srv->prefix); free(srv->certfile); free(srv->keyfile); free(srv);
            error("Failed to start server thread");
        }
        add_server(srv);
        SEXP extptr = PROTECT(R_MakeExternalPtr(srv, R_NilValue, R_NilValue));
        R_RegisterCFinalizerEx(extptr, go_server_finalizer, 1);
        UNPROTECT(1);
        return extptr;
    }
}

SEXP list_servers() {
    SEXP res = PROTECT(allocVector(VECSXP, server_count));
    int k = 0;
    for (int i = 0; i < MAX_SERVERS; ++i) {
        go_server_t* srv = server_list[i];
        if (srv && srv->running) {
            SEXP info = PROTECT(allocVector(STRSXP, 3));
            SET_STRING_ELT(info, 0, mkChar(srv->dir));
            SET_STRING_ELT(info, 1, mkChar(srv->addr));
            SET_STRING_ELT(info, 2, mkChar(srv->prefix));
            SET_VECTOR_ELT(res, k++, info);
            UNPROTECT(1);
        }
    }
    UNPROTECT(1);
    return res;
}

SEXP shutdown_server(SEXP extptr) {
    if (TYPEOF(extptr) != EXTPTRSXP) return R_NilValue;  // Handle NULL and other types
    go_server_t* srv = (go_server_t*)R_ExternalPtrAddr(extptr);
    if (!srv) return R_NilValue;
    if (srv->running) {
        PIPE_WRITE(srv->shutdown_pipe, "x", 1);
        THREAD_JOIN(srv->thread);
        srv->running = 0;
    }
    remove_server(srv);
    return R_NilValue;
}

void go_server_finalizer(SEXP extptr) {
    go_server_t* srv = (go_server_t*)R_ExternalPtrAddr(extptr);
    if (!srv) return;
    if (srv->running) {
        PIPE_WRITE(srv->shutdown_pipe, "x", 1);
        THREAD_JOIN(srv->thread);
    }
    PIPE_CLOSE(srv->shutdown_pipe);
    free(srv->dir); free(srv->addr); free(srv->prefix); free(srv);
    R_ClearExternalPtr(extptr);
}

