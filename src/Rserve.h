#ifndef _GOSERVER_RSERVE_H_
#define _GOSERVER_RSERVE_H_

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Visibility.h>
#include "serve.h"
#include "interupt.h"

#ifdef _WIN32
#include <windows.h>
#define THREAD_TYPE HANDLE
#define PIPE_TYPE int
#else
#include <pthread.h>
#define THREAD_TYPE pthread_t
#define PIPE_TYPE int
#endif

// Go function, this is also available in serve.h
// The declaration should match the one in serve.h
void RunServerWithLogging(char** dirs, char* addr, char** prefixes, int num_paths, int cors, int coop, int tls, int silent, char* certfile, char* keyfile, int shutdown_fd, int log_fd, char* auth_keys);

// Struct to hold server state for background servers
typedef struct {
    THREAD_TYPE thread; // Thread handle for background server
    char** dirs;        // Array of directories to serve
    char* addr;
    char** prefixes;    // Array of prefixes corresponding to directories
    int num_paths;      // Number of directory/prefix pairs
    int cors;
    int coop;
    int tls;
    int silent;
    char* certfile;
    char* keyfile;
    int running;
    PIPE_TYPE shutdown_pipe[2];
    PIPE_TYPE log_pipe[2];
    SEXP log_handler; // R external pointer to log handler
    SEXP original_log_function; // Store the original R log function
    char* log_file_path; // Store log file path if available
    char* auth_keys; // Comma-separated auth keys (NULL = no auth)
    // Add more fields as needed
} go_server_t;

// Start a server; if blocking, runs in foreground, else background
SEXP run_server(SEXP r_dir, SEXP r_addr, SEXP r_prefix, SEXP r_blocking, SEXP r_cors, SEXP r_coop, SEXP r_tls, SEXP r_certfile, SEXP r_keyfile, SEXP r_silent, SEXP r_log_handler, SEXP r_auth_keys);

// List all running servers (returns an R list)
SEXP list_servers();

// Shutdown a server given its external pointer
SEXP shutdown_server(SEXP extptr);

// Internal: finalizer for go_server_t external pointer
void go_server_finalizer(SEXP extptr);

// Background log handler functions
SEXP register_log_handler(SEXP s_fd, SEXP callback, SEXP user);
SEXP remove_log_handler(SEXP h_ptr);
void log_handler_finalizer(SEXP h_ptr);

#endif
