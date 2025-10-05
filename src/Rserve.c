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

// Global list of running servers with thread safety
#define MAX_SERVERS 16
static go_server_t* server_list[MAX_SERVERS] = {NULL};
static int server_count = 0;
#ifndef _WIN32
static pthread_mutex_t server_list_mutex = PTHREAD_MUTEX_INITIALIZER;
#define LOCK_SERVER_LIST() pthread_mutex_lock(&server_list_mutex)
#define UNLOCK_SERVER_LIST() pthread_mutex_unlock(&server_list_mutex)
#else
static CRITICAL_SECTION server_list_cs;
static int server_list_cs_init = 0;
#define LOCK_SERVER_LIST() do { if (!server_list_cs_init) { InitializeCriticalSection(&server_list_cs); server_list_cs_init = 1; } EnterCriticalSection(&server_list_cs); } while(0)
#define UNLOCK_SERVER_LIST() LeaveCriticalSection(&server_list_cs)
#endif

// Helper: add/remove/list servers (thread-safe)
static int add_server(go_server_t* srv) {
    LOCK_SERVER_LIST();
    for (int i = 0; i < MAX_SERVERS; ++i) {
        if (server_list[i] == NULL) {
            server_list[i] = srv;
            server_count++;
            UNLOCK_SERVER_LIST();
            return i;
        }
    }
    UNLOCK_SERVER_LIST();
    return -1;
}

static void remove_server(go_server_t* srv) {
    LOCK_SERVER_LIST();
    for (int i = 0; i < MAX_SERVERS; ++i) {
        if (server_list[i] == srv) {
            server_list[i] = NULL;
            server_count--;
            UNLOCK_SERVER_LIST();
            return;
        }
    }
    UNLOCK_SERVER_LIST();
}

// Thread entry for background server
static void* server_thread_fn(void* arg) {
    go_server_t* srv = (go_server_t*)arg;
    RunServerWithLogging(srv->dirs, srv->addr, srv->prefixes, srv->num_paths, srv->cors, srv->coop, srv->tls, srv->silent, srv->certfile, srv->keyfile, srv->shutdown_pipe[0], srv->log_pipe[1], srv->auth_keys);
    
    // Safely update running status
    LOCK_SERVER_LIST();
    srv->running = 0;
    UNLOCK_SERVER_LIST();
    
    return NULL;
}

SEXP run_server(SEXP r_dir, SEXP r_addr, SEXP r_prefix, SEXP r_blocking, SEXP r_cors, SEXP r_coop, SEXP r_tls, SEXP r_certfile, SEXP r_keyfile, SEXP r_silent, SEXP r_log_handler, SEXP r_auth_keys) {
    // Check that inputs are character vectors - now allowing vectors for dir and prefix
    if (TYPEOF(r_dir) != STRSXP || LENGTH(r_dir) < 1 ||
        TYPEOF(r_addr) != STRSXP || LENGTH(r_addr) != 1 ||
        TYPEOF(r_prefix) != STRSXP || LENGTH(r_prefix) < 1 ||
        TYPEOF(r_blocking) != LGLSXP || LENGTH(r_blocking) != 1 ||
        TYPEOF(r_cors) != LGLSXP || LENGTH(r_cors) != 1 ||
        TYPEOF(r_coop) != LGLSXP || LENGTH(r_coop) != 1 ||
        TYPEOF(r_tls) != LGLSXP || LENGTH(r_tls) != 1 ||
        TYPEOF(r_certfile) != STRSXP || LENGTH(r_certfile) != 1 ||
        TYPEOF(r_keyfile) != STRSXP || LENGTH(r_keyfile) != 1 ||
        TYPEOF(r_silent) != LGLSXP || LENGTH(r_silent) != 1) {
        error("Arguments must be correct types");
    }
    
    // Check that dir and prefix vectors have the same length
    if (LENGTH(r_dir) != LENGTH(r_prefix)) {
        error("dir and prefix vectors must have the same length");
    }
    
    // Validate log_handler: must be NULL or a function
    if (r_log_handler != R_NilValue && TYPEOF(r_log_handler) != CLOSXP) {
        error("log_handler must be a function or NULL");
    }
    
    // Validate auth_keys: must be character vector or NULL
    if (r_auth_keys != R_NilValue && TYPEOF(r_auth_keys) != STRSXP) {
        error("auth_keys must be a character vector or NULL");
    }
    
    int num_paths = LENGTH(r_dir);
    const char* addr = CHAR(STRING_ELT(r_addr, 0));
    int blocking = LOGICAL(r_blocking)[0];
    int cors = LOGICAL(r_cors)[0];
    int coop = LOGICAL(r_coop)[0];
    int tls = LOGICAL(r_tls)[0];
    const char* certfile = CHAR(STRING_ELT(r_certfile, 0));
    const char* keyfile = CHAR(STRING_ELT(r_keyfile, 0));
    int silent = LOGICAL(r_silent)[0];
    
    // Process auth_keys: convert R character vector to comma-separated string
    char* auth_keys_str = NULL;
    if (r_auth_keys != R_NilValue && LENGTH(r_auth_keys) > 0) {
        // Calculate total length needed
        int total_len = 0;
        for (int i = 0; i < LENGTH(r_auth_keys); i++) {
            total_len += strlen(CHAR(STRING_ELT(r_auth_keys, i)));
            if (i > 0) total_len += 1; // for comma
        }
        total_len += 1; // for null terminator
        
        // Build comma-separated string
        auth_keys_str = (char*)malloc(total_len);
        auth_keys_str[0] = '\0';
        for (int i = 0; i < LENGTH(r_auth_keys); i++) {
            if (i > 0) strcat(auth_keys_str, ",");
            strcat(auth_keys_str, CHAR(STRING_ELT(r_auth_keys, i)));
        }
    }
    
    PIPE_TYPE shutdown_pipe[2];
    PIPE_TYPE log_pipe[2];
    
    if (PIPE_CREATE(shutdown_pipe) != 0) {
        error("Failed to create shutdown pipe");
    }
    if (PIPE_CREATE(log_pipe) != 0) {
        PIPE_CLOSE(shutdown_pipe);
        error("Failed to create log pipe");
    }
    if (blocking) {
        go_server_t* srv = (go_server_t*)calloc(1, sizeof(go_server_t));
        
        // Allocate arrays for directories and prefixes
        srv->dirs = (char**)malloc(num_paths * sizeof(char*));
        srv->prefixes = (char**)malloc(num_paths * sizeof(char*));
        srv->num_paths = num_paths;
        
        // Copy directories and prefixes
        for (int i = 0; i < num_paths; i++) {
            srv->dirs[i] = strdup(CHAR(STRING_ELT(r_dir, i)));
            srv->prefixes[i] = strdup(CHAR(STRING_ELT(r_prefix, i)));
        }
        
        srv->addr = strdup(addr);
        srv->cors = cors;
        srv->coop = coop;
        srv->tls = tls;
        srv->certfile = strdup(certfile);
        srv->keyfile = strdup(keyfile);
        srv->silent = silent;
        srv->running = 1;
        srv->shutdown_pipe[0] = shutdown_pipe[0];
        srv->shutdown_pipe[1] = shutdown_pipe[1];
        srv->log_pipe[0] = log_pipe[0];
        srv->log_pipe[1] = log_pipe[1];
        srv->log_handler = R_NilValue;
        srv->original_log_function = R_NilValue;
        srv->log_file_path = NULL;
        srv->auth_keys = auth_keys_str ? strdup(auth_keys_str) : NULL;  // NEW: Copy auth keys
        
        // Setup log handler based on parameters
        if (!silent) {
            if (r_log_handler != R_NilValue) {
                // Store the original log function
                srv->original_log_function = r_log_handler;
                R_PreserveObject(srv->original_log_function);
                
                // Use custom log handler
                SEXP log_fd = PROTECT(ScalarInteger(srv->log_pipe[0]));
                srv->log_handler = eval(lang3(Rf_install("registerLogHandler"), log_fd, r_log_handler), R_GlobalEnv);
                if (srv->log_handler != R_NilValue) {
                    R_PreserveObject(srv->log_handler);
                }
                UNPROTECT(1);
            } else {
                // Use default log handler
                SEXP create_default_handler = PROTECT(Rf_findFun(Rf_install(".create_default_log_handler"), R_GlobalEnv));
                if (create_default_handler != R_UnboundValue) {
                    SEXP log_fd = PROTECT(ScalarInteger(srv->log_pipe[0]));
                    srv->log_handler = eval(lang2(create_default_handler, log_fd), R_GlobalEnv);
                    if (srv->log_handler != R_NilValue) {
                        R_PreserveObject(srv->log_handler);
                    }
                    UNPROTECT(2);
                } else {
                    UNPROTECT(1);
                }
            }
        }
        
        if (THREAD_CREATE(&srv->thread, server_thread_fn, srv) != 0) {
            PIPE_CLOSE(shutdown_pipe);
            PIPE_CLOSE(log_pipe);
            if (srv->log_handler != R_NilValue) R_ReleaseObject(srv->log_handler);
            if (srv->auth_keys) free(srv->auth_keys);  // NEW: Free auth keys from struct
            if (auth_keys_str) free(auth_keys_str);  // NEW: Free local auth keys string
            for (int i = 0; i < num_paths; i++) {
                free(srv->dirs[i]); free(srv->prefixes[i]);
            }
            free(srv->dirs); free(srv->prefixes); free(srv->addr); free(srv->certfile); free(srv->keyfile); free(srv);
            error("Failed to start server thread");
        }
        Rprintf("Server started in blocking mode. Press Ctrl+C to interrupt.\n");
        Rprintf("Server address: %s\n", srv->addr);
        Rprintf("Static files directories: %d paths\n", srv->num_paths);
        for (int i = 0; i < srv->num_paths; i++) {
            Rprintf("  %d: %s -> %s\n", i+1, srv->dirs[i], srv->prefixes[i]);
        }
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
        PIPE_CLOSE(log_pipe);
        if (srv->log_handler != R_NilValue) R_ReleaseObject(srv->log_handler);
        if (srv->original_log_function != R_NilValue) R_ReleaseObject(srv->original_log_function);
        if (srv->log_file_path) free(srv->log_file_path);
        if (srv->auth_keys) free(srv->auth_keys);  // NEW: Free auth keys
        for (int i = 0; i < srv->num_paths; i++) {
            free(srv->dirs[i]); free(srv->prefixes[i]);
        }
        free(srv->dirs); free(srv->prefixes); free(srv->addr); free(srv->certfile); free(srv->keyfile); free(srv);
        if (auth_keys_str) free(auth_keys_str);  // NEW: Free local auth keys string
        return R_NilValue;
    } else {
        go_server_t* srv = (go_server_t*)calloc(1, sizeof(go_server_t));
        
        // Allocate arrays for directories and prefixes
        srv->dirs = (char**)malloc(num_paths * sizeof(char*));
        srv->prefixes = (char**)malloc(num_paths * sizeof(char*));
        srv->num_paths = num_paths;
        
        // Copy directories and prefixes
        for (int i = 0; i < num_paths; i++) {
            srv->dirs[i] = strdup(CHAR(STRING_ELT(r_dir, i)));
            srv->prefixes[i] = strdup(CHAR(STRING_ELT(r_prefix, i)));
        }
        
        srv->addr = strdup(addr);
        srv->cors = cors;
        srv->coop = coop;
        srv->tls = tls;
        srv->certfile = strdup(certfile);
        srv->keyfile = strdup(keyfile);
        srv->silent = silent;
        srv->running = 1;
        srv->shutdown_pipe[0] = shutdown_pipe[0];
        srv->shutdown_pipe[1] = shutdown_pipe[1];
        srv->log_pipe[0] = log_pipe[0];
        srv->log_pipe[1] = log_pipe[1];
        srv->log_handler = R_NilValue;
        srv->original_log_function = R_NilValue;
        srv->log_file_path = NULL;
        srv->auth_keys = auth_keys_str ? strdup(auth_keys_str) : NULL;  // NEW: Copy auth keys
        
        // Setup log handler based on parameters
        if (!silent) {
            if (r_log_handler != R_NilValue) {
                // Store the original log function
                srv->original_log_function = r_log_handler;
                R_PreserveObject(srv->original_log_function);
                
                // Use custom log handler
                SEXP log_fd = PROTECT(ScalarInteger(srv->log_pipe[0]));
                srv->log_handler = eval(lang3(Rf_install("registerLogHandler"), log_fd, r_log_handler), R_GlobalEnv);
                if (srv->log_handler != R_NilValue) {
                    R_PreserveObject(srv->log_handler);
                }
                UNPROTECT(1);
            } else {
                // Use default log handler
                SEXP create_default_handler = PROTECT(Rf_findFun(Rf_install(".create_default_log_handler"), R_GlobalEnv));
                if (create_default_handler != R_UnboundValue) {
                    SEXP log_fd = PROTECT(ScalarInteger(srv->log_pipe[0]));
                    srv->log_handler = eval(lang2(create_default_handler, log_fd), R_GlobalEnv);
                    if (srv->log_handler != R_NilValue) {
                        R_PreserveObject(srv->log_handler);
                    }
                    UNPROTECT(2);
                } else {
                    UNPROTECT(1);
                }
            }
        }
        
        if (THREAD_CREATE(&srv->thread, server_thread_fn, srv) != 0) {
            PIPE_CLOSE(shutdown_pipe);
            PIPE_CLOSE(log_pipe);
            if (srv->log_handler != R_NilValue) R_ReleaseObject(srv->log_handler);
            for (int i = 0; i < num_paths; i++) {
                free(srv->dirs[i]); free(srv->prefixes[i]);
            }
            free(srv->dirs); free(srv->prefixes); free(srv->addr); free(srv->certfile); free(srv->keyfile); free(srv);
            error("Failed to start server thread");
        }
        add_server(srv);
        SEXP extptr = PROTECT(R_MakeExternalPtr(srv, R_NilValue, R_NilValue));
        R_RegisterCFinalizerEx(extptr, go_server_finalizer, 1);
        if (auth_keys_str) free(auth_keys_str);  // NEW: Free local auth keys string
        UNPROTECT(1);
        return extptr;
    }
}

SEXP list_servers() {
    LOCK_SERVER_LIST();
    
    // First pass: count active servers
    int active_count = 0;
    for (int i = 0; i < MAX_SERVERS; ++i) {
        go_server_t* srv = server_list[i];
        if (srv && srv->running) {
            active_count++;
        }
    }
    
    SEXP res = PROTECT(allocVector(VECSXP, active_count));
    int k = 0;
    
    // Second pass: collect server info
    for (int i = 0; i < MAX_SERVERS; ++i) {
        go_server_t* srv = server_list[i];
        if (srv && srv->running && srv->dirs && srv->prefixes && srv->num_paths > 0 && k < active_count) {
            SEXP info = PROTECT(allocVector(STRSXP, 9)); // Changed from 8 to 9 for auth info
            
            // For multiple directories, combine them into a single string representation
            // Calculate needed size first
            int dirs_size = 1; // for null terminator
            int prefixes_size = 1; // for null terminator
            for (int j = 0; j < srv->num_paths; j++) {
                if (srv->dirs[j] && srv->prefixes[j]) {
                    dirs_size += strlen(srv->dirs[j]);
                    prefixes_size += strlen(srv->prefixes[j]);
                    if (j > 0) {
                        dirs_size += 2; // for ", "
                        prefixes_size += 2; // for ", "
                    }
                }
            }
            
            // Allocate dynamic buffers
            char* combined_dirs = (char*)malloc(dirs_size);
            char* combined_prefixes = (char*)malloc(prefixes_size);
            combined_dirs[0] = '\0';
            combined_prefixes[0] = '\0';
            
            for (int j = 0; j < srv->num_paths; j++) {
                if (srv->dirs[j] && srv->prefixes[j]) {
                    if (j > 0) {
                        strcat(combined_dirs, ", ");
                        strcat(combined_prefixes, ", ");
                    }
                    strcat(combined_dirs, srv->dirs[j]);
                    strcat(combined_prefixes, srv->prefixes[j]);
                }
            }
            
            SET_STRING_ELT(info, 0, mkChar(combined_dirs));
            SET_STRING_ELT(info, 1, mkChar(srv->addr));
            SET_STRING_ELT(info, 2, mkChar(combined_prefixes));
            SET_STRING_ELT(info, 3, mkChar(srv->tls ? "HTTPS" : "HTTP"));
            SET_STRING_ELT(info, 4, mkChar(srv->silent ? "silent" : "logging"));
            
            // Free the temporary buffers
            free(combined_dirs);
            free(combined_prefixes);
            
            // Extract actual log handler information
            const char* log_handler_type = "none";
            const char* log_destination = "none";
            const char* log_function_info = "none";
            
            if (!srv->silent) {
                if (srv->original_log_function != R_NilValue) {
                    // Get function as deparsed string
                    SEXP deparse_call = PROTECT(lang2(Rf_install("deparse"), srv->original_log_function));
                    SEXP deparsed_func = R_tryEval(deparse_call, R_GlobalEnv, NULL);
                    
                    if (deparsed_func != NULL && LENGTH(deparsed_func) > 0) {
                        const char* func_text = CHAR(STRING_ELT(deparsed_func, 0));
                        
                        // Store first line of function for identification
                        log_function_info = func_text;
                        
                        // Analyze function to determine type and destination
                        if (strstr(func_text, "file") != NULL && strstr(func_text, "append") != NULL) {
                            log_handler_type = "file_logger";
                            
                            // Try to extract filename from the function environment/closure
                            if (srv->log_file_path != NULL) {
                                log_destination = srv->log_file_path;
                            } else if (strstr(func_text, "logfile") != NULL) {
                                log_destination = "custom_file_var";
                            } else {
                                log_destination = "file_unknown";
                            }
                        } else if (strstr(func_text, "cat") != NULL) {
                            log_handler_type = "console_logger";
                            log_destination = "console";
                        } else {
                            log_handler_type = "custom_function";
                            log_destination = "custom";
                        }
                    } else {
                        log_handler_type = "custom_unparseable";
                        log_destination = "unknown";
                        log_function_info = "<unparseable function>";
                    }
                    UNPROTECT(1); // deparse_call
                } else {
                    log_handler_type = "default";
                    log_destination = "console";
                    log_function_info = ".default_log_callback";
                }
            }
            
            SET_STRING_ELT(info, 5, mkChar(log_handler_type));
            SET_STRING_ELT(info, 6, mkChar(log_destination));
            SET_STRING_ELT(info, 7, mkChar(log_function_info));
            
            // Add authentication information
            const char* auth_status = "none";
            if (srv->auth_keys != NULL && strlen(srv->auth_keys) > 0) {
                auth_status = srv->auth_keys; // Show the actual keys (could be "enabled" for privacy)
            }
            SET_STRING_ELT(info, 8, mkChar(auth_status));
            
            SET_VECTOR_ELT(res, k++, info);
            UNPROTECT(1);
        }
    }
    
    UNLOCK_SERVER_LIST();
    UNPROTECT(1);
    return res;
}

SEXP shutdown_server(SEXP extptr) {
    if (TYPEOF(extptr) != EXTPTRSXP) return R_NilValue;  // Handle NULL and other types
    go_server_t* srv = (go_server_t*)R_ExternalPtrAddr(extptr);
    if (!srv) return R_NilValue;
    
    // Thread-safe shutdown with protection against double shutdown
    LOCK_SERVER_LIST();
    int was_running = srv->running;
    if (was_running) {
        srv->running = 0;  // Mark as shutting down immediately
        UNLOCK_SERVER_LIST();
        
        // Remove log handler first to prevent callbacks during shutdown
        if (srv->log_handler != R_NilValue) {
            SEXP remove_handler = PROTECT(Rf_findFun(Rf_install("removeLogHandler"), R_GlobalEnv));
            if (remove_handler != R_UnboundValue) {
                R_tryEval(lang2(remove_handler, srv->log_handler), R_GlobalEnv, NULL);
            }
            UNPROTECT(1);
            R_ReleaseObject(srv->log_handler);
            srv->log_handler = R_NilValue;
        }
        
        // Send shutdown signal and wait for thread to complete
        PIPE_WRITE(srv->shutdown_pipe, "x", 1);
        THREAD_JOIN(srv->thread);
        
        // Remove from server list after thread has completed
        remove_server(srv);
    } else {
        UNLOCK_SERVER_LIST();
    }
    return R_NilValue;
}

void go_server_finalizer(SEXP extptr) {
    go_server_t* srv = (go_server_t*)R_ExternalPtrAddr(extptr);
    if (!srv) return;
    
    // Thread-safe shutdown check and cleanup
    LOCK_SERVER_LIST();
    int was_running = srv->running;
    if (was_running) {
        srv->running = 0;  // Mark as shutting down
        UNLOCK_SERVER_LIST();
        
        // Remove log handler first to prevent callbacks during shutdown
        if (srv->log_handler != R_NilValue) {
            SEXP remove_handler = PROTECT(Rf_findFun(Rf_install("removeLogHandler"), R_GlobalEnv));
            if (remove_handler != R_UnboundValue) {
                R_tryEval(lang2(remove_handler, srv->log_handler), R_GlobalEnv, NULL);
            }
            UNPROTECT(1);
        }
        
        PIPE_WRITE(srv->shutdown_pipe, "x", 1);
        THREAD_JOIN(srv->thread);
        
        // Remove from server list
        remove_server(srv);
    } else {
        UNLOCK_SERVER_LIST();
    }
    
    // Clean up resources
    PIPE_CLOSE(srv->shutdown_pipe);
    PIPE_CLOSE(srv->log_pipe);
    if (srv->log_handler != R_NilValue) R_ReleaseObject(srv->log_handler);
    if (srv->dirs && srv->prefixes) {
        for (int i = 0; i < srv->num_paths; i++) {
            if (srv->dirs[i]) free(srv->dirs[i]);
            if (srv->prefixes[i]) free(srv->prefixes[i]);
        }
        free(srv->dirs);
        free(srv->prefixes);
    }
    if (srv->addr) free(srv->addr);
    if (srv->certfile) free(srv->certfile);
    if (srv->keyfile) free(srv->keyfile);
    if (srv->auth_keys) free(srv->auth_keys);
    free(srv);
    R_ClearExternalPtr(extptr);
}

