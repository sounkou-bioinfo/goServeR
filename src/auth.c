#include <R.h>
#include <Rinternals.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "Rserve.h"

#ifdef _WIN32
#include <io.h>
#include <fcntl.h>
#define PIPE_CREATE(p) _pipe(p, 512, _O_BINARY)
#define PIPE_WRITE(fd, buf, n) _write(fd, buf, n)
#define PIPE_CLOSE(fd) _close(fd)
#else
#include <unistd.h>
#define PIPE_CREATE(p) pipe(p)
#define PIPE_WRITE(fd, buf, n) write(fd, buf, n)
#define PIPE_CLOSE(fd) close(fd)
#endif

// Helper: add key to tracking array
static void add_key_to_list(auth_context_t* ctx, const char* key) {
    if (!ctx || !key || strlen(key) == 0) {
        return; // Invalid input
    }
    
    // Check if key already exists (only if we have keys)
    if (ctx->current_keys && ctx->num_keys > 0) {
        for (int i = 0; i < ctx->num_keys && i < ctx->key_capacity; i++) {
            if (ctx->current_keys[i] && strcmp(ctx->current_keys[i], key) == 0) {
                return; // Already exists
            }
        }
    }
    
    // Expand array if needed
    if (ctx->num_keys >= ctx->key_capacity) {
        int old_capacity = ctx->key_capacity;
        ctx->key_capacity = ctx->key_capacity == 0 ? 4 : ctx->key_capacity * 2;
        char** new_keys = (char**)realloc(ctx->current_keys, 
                                         ctx->key_capacity * sizeof(char*));
        if (!new_keys) {
            Rf_error("Failed to reallocate keys array");
        }
        ctx->current_keys = new_keys;
        
        // Initialize new slots to NULL
        for (int i = old_capacity; i < ctx->key_capacity; i++) {
            ctx->current_keys[i] = NULL;
        }
    }
    
    // Add new key - double check bounds
    if (ctx->num_keys >= ctx->key_capacity) {
        Rf_error("Key array capacity exceeded unexpectedly");
    }
    
    ctx->current_keys[ctx->num_keys] = (char*)malloc(strlen(key) + 1);
    if (!ctx->current_keys[ctx->num_keys]) {
        Rf_error("Failed to allocate key string");
    }
    strcpy(ctx->current_keys[ctx->num_keys], key);
    ctx->num_keys++;
}

// Helper: remove key from tracking array
static void remove_key_from_list(auth_context_t* ctx, const char* key) {
    if (!ctx || !key) {
        return; // Invalid input
    }
    
    // Check if we have no keys or no array allocated
    if (!ctx->current_keys || ctx->num_keys <= 0 || ctx->key_capacity <= 0) {
        return; // Empty list or no allocation
    }
    
    for (int i = 0; i < ctx->num_keys; i++) {
        if (ctx->current_keys[i] && strcmp(ctx->current_keys[i], key) == 0) {
            // Free the key string
            free(ctx->current_keys[i]);
            ctx->current_keys[i] = NULL;
            
            // Shift remaining keys down (properly compact the array)
            for (int j = i; j < ctx->num_keys - 1; j++) {
                ctx->current_keys[j] = ctx->current_keys[j + 1];
            }
            
            // Decrement count and clear the last slot
            ctx->num_keys--;
            if (ctx->num_keys >= 0 && ctx->num_keys < ctx->key_capacity) {
                ctx->current_keys[ctx->num_keys] = NULL;
            }
            return;
        }
    }
    // Key not found - this is handled gracefully
}

// Helper: clear all keys from tracking array
static void clear_all_keys(auth_context_t* ctx) {
    if (!ctx) {
        return; // Invalid input
    }
    
    if (ctx->current_keys && ctx->key_capacity > 0) {
        // Free all allocated key strings
        for (int i = 0; i < ctx->key_capacity; i++) {
            if (ctx->current_keys[i]) {
                free(ctx->current_keys[i]);
                ctx->current_keys[i] = NULL;
            }
        }
        ctx->num_keys = 0;
    }
}

// Helper: cleanup auth context
void cleanup_auth_context(auth_context_t* ctx) {
    if (!ctx) {
        return; // Null pointer, nothing to clean up
    }
    
    // Close write end pipe safely (only if still open)
    if (ctx->auth_pipe_write_fd >= 0) {
        PIPE_CLOSE(ctx->auth_pipe_write_fd);
        ctx->auth_pipe_write_fd = -1;
    }
    
    // Don't close read end here since Go manages it
    ctx->auth_pipe_fd = -1;
    
    // Free key strings safely - only free non-NULL pointers
    if (ctx->current_keys) {
        for (int i = 0; i < ctx->key_capacity; i++) {
            if (ctx->current_keys[i]) {
                free(ctx->current_keys[i]);
                ctx->current_keys[i] = NULL;
            }
        }
        free(ctx->current_keys);
        ctx->current_keys = NULL;
    }
    ctx->num_keys = 0;
    ctx->key_capacity = 0;
    
    free(ctx);
}

// Create auth context for a server (no longer standalone)
auth_context_t* create_server_auth_context(void) {
    int pipe_fds[2];
    if (PIPE_CREATE(pipe_fds) == -1) {
        Rf_error("Failed to create auth pipe");
    }
    
    // pipe_fds[0] = read end (for Go)
    // pipe_fds[1] = write end (for C/R)
    
    // Create auth context
    auth_context_t* ctx = (auth_context_t*)malloc(sizeof(auth_context_t));
    if (!ctx) {
        PIPE_CLOSE(pipe_fds[0]);
        PIPE_CLOSE(pipe_fds[1]);
        Rf_error("Failed to allocate auth context");
    }
    
    // Initialize all fields properly
    ctx->auth_pipe_fd = pipe_fds[0];
    ctx->auth_pipe_write_fd = pipe_fds[1];
    ctx->current_keys = NULL;
    ctx->num_keys = 0;
    ctx->key_capacity = 0;
    
    return ctx;
}

// Manage auth keys on a server (add/remove/clear)
SEXP manage_server_auth(SEXP server_handle, SEXP key, SEXP action) {
    if (TYPEOF(server_handle) != EXTPTRSXP) {
        Rf_error("Invalid server handle");
    }
    
    go_server_t* srv = (go_server_t*)R_ExternalPtrAddr(server_handle);
    if (!srv) {
        Rf_error("Server context is NULL");
    }
    
    if (!srv->auth_context) {
        Rf_error("Server has no auth context - auth not enabled for this server");
    }
    
    auth_context_t* ctx = srv->auth_context;
    
    // Check if pipe is still valid - if not, only update local tracking
    int pipe_valid = (ctx->auth_pipe_write_fd >= 0);
    
    // Validate input parameters
    if (TYPEOF(key) != STRSXP || LENGTH(key) != 1) {
        Rf_error("Key must be a single character string");
    }
    if (TYPEOF(action) != STRSXP || LENGTH(action) != 1) {
        Rf_error("Action must be a single character string");
    }
    
    const char* key_str = CHAR(STRING_ELT(key, 0));
    const char* action_str = CHAR(STRING_ELT(action, 0));
    
    // Validate that strings are not NULL
    if (!key_str || !action_str) {
        Rf_error("Key and action cannot be NULL");
    }
    
    // Write to pipe only if it's still valid
    if (pipe_valid) {
        // Format: "ACTION:KEY\n"
        char command[512];
        snprintf(command, sizeof(command), "%s:%s\n", action_str, key_str);
        
        // Write to pipe
        ssize_t written = PIPE_WRITE(ctx->auth_pipe_write_fd, command, strlen(command));
        if (written == -1) {
            // Pipe write failed - mark pipe as invalid but continue with local tracking
            pipe_valid = 0;
        }
    }
    
    // Update local tracking regardless of pipe status
    if (strcmp(action_str, "ADD") == 0) {
        add_key_to_list(ctx, key_str);
    } else if (strcmp(action_str, "REMOVE") == 0) {
        // Always try to remove - remove_key_from_list handles non-existent keys gracefully
        remove_key_from_list(ctx, key_str);
    } else if (strcmp(action_str, "CLEAR") == 0) {
        clear_all_keys(ctx);
    }
    
    return R_NilValue;
}

// List current auth keys for a server
SEXP list_server_auth_keys(SEXP server_handle) {
    if (TYPEOF(server_handle) != EXTPTRSXP) {
        Rf_error("Invalid server handle");
    }
    
    go_server_t* srv = (go_server_t*)R_ExternalPtrAddr(server_handle);
    if (!srv) {
        Rf_error("Server context is NULL");
    }
    
    if (!srv->auth_context) {
        Rf_error("Server has no auth context - auth not enabled for this server");
    }
    
    auth_context_t* ctx = srv->auth_context;
    
    // If no keys or no array allocated, return empty vector
    if (!ctx->current_keys || ctx->num_keys <= 0 || ctx->key_capacity <= 0) {
        SEXP result = PROTECT(allocVector(STRSXP, 0));
        UNPROTECT(1);
        return result;
    }
    
    // Count valid (non-NULL) keys first
    int valid_keys = 0;
    for (int i = 0; i < ctx->num_keys && i < ctx->key_capacity; i++) {
        if (ctx->current_keys[i]) {
            valid_keys++;
        }
    }
    
    // Create R character vector
    SEXP result = PROTECT(allocVector(STRSXP, valid_keys));
    
    // Fill the result with valid keys only
    int result_idx = 0;
    for (int i = 0; i < ctx->num_keys && i < ctx->key_capacity && result_idx < valid_keys; i++) {
        if (ctx->current_keys[i]) {
            SET_STRING_ELT(result, result_idx, mkChar(ctx->current_keys[i]));
            result_idx++;
        }
    }
    
    UNPROTECT(1);
    return result;
}

// Add initial auth keys to a server
SEXP add_initial_server_auth_keys(SEXP server_handle, SEXP keys) {
    if (TYPEOF(server_handle) != EXTPTRSXP) {
        Rf_error("Invalid server handle");
    }
    
    if (TYPEOF(keys) != STRSXP) {
        Rf_error("Keys must be a character vector");
    }
    
    go_server_t* srv = (go_server_t*)R_ExternalPtrAddr(server_handle);
    if (!srv) {
        Rf_error("Server context is NULL");
    }
    
    if (!srv->auth_context) {
        Rf_error("Server has no auth context - auth not enabled for this server");
    }
    
    auth_context_t* ctx = srv->auth_context;
    
    int n_keys = LENGTH(keys);
    for (int i = 0; i < n_keys; i++) {
        const char* key = CHAR(STRING_ELT(keys, i));
        
        // Send to Go (if pipe is valid)
        if (ctx->auth_pipe_write_fd >= 0) {
            char command[512];
            snprintf(command, sizeof(command), "ADD:%s\n", key);
            ssize_t written = PIPE_WRITE(ctx->auth_pipe_write_fd, command, strlen(command));
            if (written == -1) {
                Rf_warning("Failed to write initial auth key to pipe");
            }
        }
        
        // Add to local tracking
        add_key_to_list(ctx, key);
    }
    
    return R_NilValue;
}
