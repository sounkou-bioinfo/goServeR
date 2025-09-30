#include <R.h>
#include <Rinternals.h>
#include <stdlib.h>
#include <stdio.h>
#include "Rserve.h"
#include "interupt.h"
#include <pthread.h>
#include <string.h>
#include <unistd.h> 
#include <sys/wait.h>

// Global list of running servers (simple array for demo, use better structure for production)
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
    // Pass the read end of the pipe to Go as an int
    RunServerWithShutdown(srv->dir, srv->addr, srv->prefix, srv->shutdown_pipe[0]);
    srv->running = 0;
    return NULL;
}

SEXP run_server(SEXP r_dir, SEXP r_addr, SEXP r_prefix, SEXP r_blocking) {
    // Check that inputs are character vectors of length 1
    if (TYPEOF(r_dir) != STRSXP || LENGTH(r_dir) != 1 ||
        TYPEOF(r_addr) != STRSXP || LENGTH(r_addr) != 1 ||
        TYPEOF(r_prefix) != STRSXP || LENGTH(r_prefix) != 1 ||
        TYPEOF(r_blocking) != LGLSXP || LENGTH(r_blocking) != 1) {
        error("Arguments must be character strings");
    }
    
    // Convert R character vectors to C strings
    const char* dir = CHAR(STRING_ELT(r_dir, 0));
    const char* addr = CHAR(STRING_ELT(r_addr, 0));
    const char* prefix = CHAR(STRING_ELT(r_prefix, 0));
    
    // Print debug info
    Rprintf("Starting server with: dir=%s, addr=%s, prefix=%s\n", dir, addr, prefix);
    
    int blocking = LOGICAL(r_blocking)[0];
    int shutdown_pipe[2];
    if (pipe(shutdown_pipe) != 0) {
        error("Failed to create shutdown pipe");
    }
    if (blocking) {
        // Foreground: run Go server in this process, but in a thread, so we can check for interrupts
        go_server_t* srv = (go_server_t*)calloc(1, sizeof(go_server_t));
        srv->dir = strdup(dir);
        srv->addr = strdup(addr);
        srv->prefix = strdup(prefix);
        srv->running = 1;
        srv->shutdown_pipe[0] = shutdown_pipe[0];
        srv->shutdown_pipe[1] = shutdown_pipe[1];
        if (pthread_create(&srv->thread, NULL, server_thread_fn, srv) != 0) {
            close(shutdown_pipe[0]); close(shutdown_pipe[1]);
            free(srv->dir); free(srv->addr); free(srv->prefix); free(srv);
            error("Failed to start server thread");
        }
        Rprintf("Server started in blocking mode. Press Ctrl+C to interrupt.\n");
        add_server(srv);
        // Now, wait and check for interrupt
        while (srv->running) {
            if (pending_interrupt()) {
                ssize_t _unused = write(shutdown_pipe[1], "x", 1);
                (void)_unused;
                break;
            }
            usleep(200000); // 200ms
        }
        pthread_join(srv->thread, NULL);
        srv->running = 0;
        remove_server(srv);
        close(shutdown_pipe[0]);
        close(shutdown_pipe[1]);
        free(srv->dir); free(srv->addr); free(srv->prefix); free(srv);
        return R_NilValue;
    } else {
        // Background: allocate struct, start thread, return extptr
        go_server_t* srv = (go_server_t*)calloc(1, sizeof(go_server_t));
        srv->dir = strdup(dir);
        srv->addr = strdup(addr);
        srv->prefix = strdup(prefix);
        srv->running = 1;
        srv->shutdown_pipe[0] = shutdown_pipe[0];
        srv->shutdown_pipe[1] = shutdown_pipe[1];
        if (pthread_create(&srv->thread, NULL, server_thread_fn, srv) != 0) {
            close(shutdown_pipe[0]); close(shutdown_pipe[1]);
            free(srv->dir); free(srv->addr); free(srv->prefix); free(srv);
            error("Failed to start server thread");
        }
        add_server(srv);
        SEXP extptr = PROTECT(R_MakeExternalPtr(srv, R_NilValue, R_NilValue));
        R_RegisterCFinalizerEx(extptr, go_server_finalizer, 1); // use 1 instead of TRUE
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
    go_server_t* srv = (go_server_t*)R_ExternalPtrAddr(extptr);
    if (!srv) return R_NilValue;
    if (srv->running) {
        // Signal shutdown to Go by writing to the pipe
        ssize_t _unused = write(srv->shutdown_pipe[1], "x", 1);
        (void)_unused;
        pthread_join(srv->thread, NULL);
        srv->running = 0;
    }
    remove_server(srv);
    return R_NilValue;
}

void go_server_finalizer(SEXP extptr) {
    go_server_t* srv = (go_server_t*)R_ExternalPtrAddr(extptr);
    if (!srv) return;
    if (srv->running) {
        ssize_t _unused = write(srv->shutdown_pipe[1], "x", 1);
        (void)_unused;
        pthread_join(srv->thread, NULL);
    }
    close(srv->shutdown_pipe[0]);
    close(srv->shutdown_pipe[1]);
    free(srv->dir); free(srv->addr); free(srv->prefix); free(srv);
    R_ClearExternalPtr(extptr);
}

