#ifndef _GOSERVER_RSERVE_H_
#define _GOSERVER_RSERVE_H_

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Visibility.h>
#include "serve.h"
#include "interupt.h"
#include <pthread.h>

// Go function, this is also available in serve.h
// The declaration should match the one in serve.h
extern void RunServer(char* dir, char* addr, char* prefix);
extern void RunServerWithShutdown(char* dir, char* addr, char* prefix, int shutdown_fd);

// Struct to hold server state for background servers
typedef struct {
    pthread_t thread; // Thread handle for background server
    char* dir;
    char* addr;
    char* prefix;
    int running;
    int shutdown_pipe[2];
    // Add more fields as needed
} go_server_t;

// Start a server; if blocking, runs in foreground, else background
SEXP run_server(SEXP r_dir, SEXP r_addr, SEXP r_prefix, SEXP r_blocking);

// List all running servers (returns an R list)
SEXP list_servers();

// Shutdown a server given its external pointer
SEXP shutdown_server(SEXP extptr);

// Internal: finalizer for go_server_t external pointer
void go_server_finalizer(SEXP extptr);

#endif
