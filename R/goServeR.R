#' @useDynLib goserveR, .registration = TRUE
NULL

#' runServer
#'
#' Run the go http server (blocking or background)
#'
#' @param dir character vector of directories to serve
#' @param addr address
#' @param prefix character vector of server prefixes (must have same length as dir)
#' @param blocking logical, if FALSE runs in background and returns a handle
#' @param cors logical, enable CORS headers
#' @param coop logical, enable COOP/COEP headers
#' @param tls logical, enable TLS (HTTPS)
#' @param certfile path to TLS certificate file
#' @param keyfile path to TLS key file
#' @param silent logical, suppress server logs
#' @param log_handler function, custom log handler function(handler, message, user)
#' @param auth_keys character vector of API keys for authentication. Default c() = no auth
#' @param auth logical, enable dynamic authentication system (non-blocking mode only)
#' @param initial_keys character vector of initial API keys for dynamic auth system
#' @param mustWork logical, if TRUE and non-blocking, will check if server actually started and throw error if it failed (default FALSE for backward compatibility)
#' @param ... additional arguments passed to the server
#'
#' @return NULL (if blocking) or an external pointer (if non-blocking)
#' @export
#' @examples
#' \dontrun{
#' # Start a blocking server (will block the R session)
#' # runServer(dir = ".", addr = "0.0.0.0:8080")
#'
#' # Start a background server (returns a handle)
#' h <- runServer(dir = ".", addr = "0.0.0.0:8080", blocking = FALSE)
#'
#' # Start a server with static auth keys (backward compatible)
#' h <- runServer(
#'     dir = ".", addr = "0.0.0.0:8080", blocking = FALSE,
#'     auth_keys = c("secret123", "token456")
#' )
#'
#' # Start a server with dynamic auth system
#' h <- runServer(
#'     dir = ".", addr = "0.0.0.0:8080", blocking = FALSE,
#'     auth = TRUE, initial_keys = c("secret123")
#' )
#'
#' # Manage auth keys dynamically (only with auth=TRUE)
#' auth <- attr(h, "auth")
#' addAuthKey(auth, "new_key_456")
#' removeAuthKey(auth, "secret123")
#' listAuthKeys(auth)
#'
#' # Start a server serving multiple directories
#' h <- runServer(
#'     dir = c("./data", "./docs", "."),
#'     prefix = c("/api/data", "/docs", "/files"),
#'     addr = "0.0.0.0:8080",
#'     blocking = FALSE
#' )
#'
#' # Start a server with custom log handler
#' logfile <- tempfile("server_", fileext = ".log")
#' h <- runServer(
#'     dir = ".", addr = "0.0.0.0:8080", blocking = FALSE,
#'     log_handler = function(handler, message, user) {
#'         cat("[CUSTOM]", message, file = logfile, append = TRUE)
#'     }
#' )
#'
#' # List all running background servers
#' listServers()
#'
#' # Get a summary view
#' summary(listServers())
#'
#' # Shutdown a background server
#' shutdownServer(h)
#' }
runServer <- function(
    dir = getwd(),
    addr = "0.0.0.0:8181",
    prefix = "",
    blocking = TRUE,
    cors = FALSE,
    coop = FALSE,
    tls = FALSE,
    certfile = "cert.pem",
    keyfile = "key.pem",
    silent = FALSE,
    log_handler = NULL,
    auth_keys = c(),
    auth = FALSE,
    initial_keys = c(),
    mustWork = FALSE,
    ...) {
    # Normalize paths to prevent basic traversal
    if (length(dir) == 1) {
        dir <- normalizePath(dir, winslash = "/", mustWork = TRUE)
    } else {
        dir <- sapply(
            dir,
            function(d) normalizePath(d, winslash = "/", mustWork = TRUE),
            USE.NAMES = FALSE
        )
    }

    # Validate input parameters
    stopifnot(
        is.character(dir) && length(dir) >= 1 && all(!is.na(dir)) && all(dir != ""),
        all(sapply(dir, dir.exists)),
        is.character(addr) && length(addr) == 1 && !is.na(addr),
        grepl("^[^:]+:[0-9]+$", addr), # Check address format (host:port)
        is.character(prefix) && length(prefix) >= 1 && all(!is.na(prefix)),
        length(prefix) == length(dir), # dir and prefix must have same length
        is.logical(blocking) && length(blocking) == 1,
        is.logical(cors) && length(cors) == 1,
        is.logical(coop) && length(coop) == 1,
        is.logical(tls) && length(tls) == 1,
        is.character(certfile) && length(certfile) == 1,
        is.character(keyfile) && length(keyfile) == 1,
        is.logical(silent) && length(silent) == 1,
        is.logical(auth) && length(auth) == 1,
        is.logical(mustWork) && length(mustWork) == 1
    )

    # Validate auth parameters
    if (!is.null(auth_keys) && !is.character(auth_keys)) {
        stop("auth_keys must be a character vector or NULL")
    }
    if (!is.null(initial_keys) && !is.character(initial_keys)) {
        stop("initial_keys must be a character vector or NULL")
    }

    # Validate log_handler if provided
    if (!is.null(log_handler) && !is.function(log_handler)) {
        stop("log_handler must be a function or NULL")
    }

    # Additional validation for address format
    addr_parts <- strsplit(addr, ":")[[1]]
    if (length(addr_parts) != 2) {
        stop("Address must be in format 'host:port'")
    }

    port <- as.numeric(addr_parts[2])
    if (is.na(port) || port < 1 || port > 65535) {
        stop("Port must be a number between 1 and 65535")
    }

    # Determine final auth keys (backward compatibility)
    final_auth_keys <- auth_keys
    if (length(initial_keys) > 0) {
        final_auth_keys <- c(final_auth_keys, initial_keys)
    }

    # Enable auth context if either auth=TRUE OR auth_keys are provided (backward compatibility)
    auth_enabled <- auth || length(final_auth_keys) > 0

    if (auth_enabled) {
        if (length(final_auth_keys) == 0) {
            final_auth_keys <- "__AUTH_ENABLED__" # Special marker for empty auth
        } else {
            # Prepend marker to indicate auth is enabled with initial keys
            final_auth_keys <- c("__AUTH_ENABLED__", final_auth_keys)
        }
    }

    if (blocking) {
        # For blocking mode, use old system
        invisible(.Call(
            RC_StartServer,
            dir,
            addr,
            prefix,
            blocking,
            cors,
            coop,
            tls,
            certfile,
            keyfile,
            silent,
            log_handler,
            final_auth_keys
        ))
    } else {
        # For non-blocking mode, support dynamic auth if requested
        server_handle <- .Call(
            RC_StartServer,
            dir,
            addr,
            prefix,
            blocking,
            cors,
            coop,
            tls,
            certfile,
            keyfile,
            silent,
            log_handler,
            final_auth_keys
        )

        # For new auth system: if auth=TRUE, explicitly add initial keys to auth context
        if (auth_enabled) {
            # Get the actual initial keys (excluding the marker)
            actual_initial_keys <- if (length(initial_keys) > 0) {
                initial_keys
            } else if (length(auth_keys) > 0) {
                auth_keys
            } else {
                c()
            }

            # Add initial keys to the server's auth context if any exist
            if (length(actual_initial_keys) > 0) {
                .Call(RC_add_initial_server_auth_keys, server_handle, actual_initial_keys)
            }
        }

        # Set auth attribute to the server handle itself for the new system
        if (auth_enabled) {
            attr(server_handle, "auth") <- server_handle # Server handles its own auth now
        }

        # Check if server actually started when mustWork = TRUE
        if (mustWork && !blocking) {
            # Give the server a moment to start
            Sys.sleep(0.5)

            # Check if server is actually running
            if (!isRunning(server_handle)) {
                stop("Server failed to start. Check address availability and permissions.")
            }
        }

        return(server_handle)
    }
}

#' listServers
#' List all running background servers with detailed information
#' @return a server_list S3 object containing server information
#' @export
listServers <- function() {
    # Add error handling to prevent segfaults
    tryCatch(
        {
            servers <- .Call(RC_list_servers)

            # Check if the result is NULL or corrupted
            if (is.null(servers)) {
                result <- list()
                class(result) <- "server_list"
                return(result)
            }

            # Format the output for better readability
            if (length(servers) == 0) {
                result <- list()
                class(result) <- "server_list"
                return(result)
            } # Add names to make the output more readable
            formatted_servers <- lapply(seq_along(servers), function(i) {
                server_info <- servers[[i]]

                # Check if server_info is NULL or not a vector
                if (is.null(server_info) || length(server_info) == 0) {
                    return(NULL)
                }

                # Ensure we have the expected number of elements
                if (length(server_info) < 9) {
                    warning("Server info has fewer than expected elements")
                    return(NULL)
                }

                names(server_info) <- c(
                    "directory",
                    "address",
                    "prefix",
                    "protocol",
                    "logging",
                    "log_handler",
                    "log_destination",
                    "log_function",
                    "auth_keys"
                )

                # Enhance log handler and destination information
                log_handler_type <- as.character(server_info[6])
                log_destination <- as.character(server_info[7])
                log_function_info <- as.character(server_info[8])
                auth_keys_info <- as.character(server_info[9])

                # For file loggers, try to get more specific information
                if (
                    log_handler_type == "file_logger" &&
                        log_destination %in% c("custom_file", "custom")
                ) {
                    log_destination <- "file (path in closure)"
                }

                # Format auth information - use the actual status from C code
                auth_status <- auth_keys_info
                if (auth_status == "none") {
                    auth_status <- "disabled"
                    key_summary <- "none"
                } else if (auth_status %in% c("enabled", "configured")) {
                    # Auth is enabled/configured, try to get key count if possible
                    # For the auth_keys field, we'll show a summary rather than actual keys for security
                    key_summary <- auth_status
                } else {
                    key_summary <- auth_status
                }

                # Create a more readable format
                structure(
                    list(
                        directory = as.character(server_info[1]),
                        address = as.character(server_info[2]),
                        prefix = as.character(server_info[3]),
                        protocol = as.character(server_info[4]),
                        logging = as.character(server_info[5]),
                        log_handler = log_handler_type,
                        log_destination = log_destination,
                        log_function = log_function_info,
                        authentication = auth_status,
                        auth_keys = key_summary
                    ),
                    class = "server_info"
                )
            })

            # Filter out NULL entries
            formatted_servers <- formatted_servers[
                !sapply(formatted_servers, is.null)
            ]

            # Set class for the list
            class(formatted_servers) <- "server_list"
            return(formatted_servers)
        },
        error = function(e) {
            # Return empty server list on error to prevent crashes
            warning("Error in listServers: ", e$message)
            result <- list()
            class(result) <- "server_list"
            return(result)
        }
    )
}

#' shutdownServer
#' Shutdown a background server
#' @param handle external pointer returned by runServer(blocking=FALSE)
#' @export
shutdownServer <- function(handle) {
    invisible(.Call(RC_shutdown_server, handle))
}

#' isRunning
#' Check if a background server is still running
#' @param handle external pointer returned by runServer(blocking=FALSE)
#' @return logical, TRUE if server is running, FALSE otherwise
#' @export
#' @examples
#' \dontrun{
#' h <- runServer(dir = ".", addr = "127.0.0.1:8080", blocking = FALSE)
#' isRunning(h) # TRUE
#' shutdownServer(h)
#' isRunning(h) # FALSE
#' }
isRunning <- function(handle) {
    if (!inherits(handle, "externalptr")) {
        return(FALSE)
    }
    .Call(RC_is_running, handle)
}

#' StartServer (advanced/manual use)
#' Start a server (C-level, advanced)
#' @param dir character vector of directories to serve
#' @param addr address
#' @param prefix character vector of server prefixes (must have same length as dir)
#' @param blocking logical, if FALSE runs in background and returns a handle
#' @param cors logical, enable CORS headers
#' @param coop logical, enable COOP/COEP headers
#' @param tls logical, enable TLS (HTTPS)
#' @param certfile path to TLS certificate file
#' @param keyfile path to TLS key file
#' @param silent logical, suppress server logs
#' @param log_handler function, custom log handler function(handler, message, user)
#' @param auth_keys character vector of API keys for authentication
#' @export
StartServer <- function(
    dir,
    addr,
    prefix,
    blocking,
    cors = FALSE,
    coop = FALSE,
    tls = FALSE,
    certfile = "cert.pem",
    keyfile = "key.pem",
    silent = FALSE,
    log_handler = NULL,
    auth_keys = c()) {
    .Call(
        RC_StartServer,
        dir,
        addr,
        prefix,
        blocking,
        cors,
        coop,
        tls,
        certfile,
        keyfile,
        silent,
        log_handler,
        auth_keys
    )
}

# Log handler functions

#' Register a log handler for a file descriptor
#'
#' @param fd file descriptor to monitor
#' @param callback R function to call when data is available
#' @param user user data passed to callback
#' @return external pointer to log handler
#' @export
registerLogHandler <- function(fd, callback, user = NULL) {
    .Call(RC_register_log_handler, as.integer(fd), callback, user)
}

#' Remove a log handler
#'
#' @param handler external pointer to log handler
#' @return logical indicating success
#' @export
removeLogHandler <- function(handler) {
    .Call(RC_remove_log_handler, handler)
}

# Default log handlers

#' Create default console log handler
#'
#' @param fd file descriptor for log pipe
#' @return external pointer to log handler
#' @export
.create_default_log_handler <- function(fd) {
    registerLogHandler(fd, .default_log_callback, NULL)
}

#' Default log callback - writes to console
#'
#' @param handler external pointer to handler
#' @param message log message
#' @param user user data (unused)
#' @export
.default_log_callback <- function(handler, message, user) {
    cat("[goserveR]", message)
    utils::flush.console()
}

#' Create file log handler
#'
#' @param fd file descriptor for log pipe
#' @param logfile path to log file
#' @return external pointer to log handler
#' @export
createFileLogHandler <- function(
    fd,
    logfile = tempfile("goserveR_", fileext = ".log")) {
    # Create a closure that captures the logfile path
    file_logger_with_path <- function(handler, message, captured_logfile) {
        cat(message, file = captured_logfile, append = TRUE)
    }

    # Store the logfile path as an attribute for later retrieval
    attr(file_logger_with_path, "logfile") <- logfile

    registerLogHandler(fd, file_logger_with_path, logfile)
}

#' Create silent log handler (no-op)
#'
#' @param fd file descriptor for log pipe
#' @return external pointer to log handler
#' @export
createSilentLogHandler <- function(fd) {
    registerLogHandler(
        fd,
        function(handler, message, user) {
            # Do nothing - silent handler
        },
        NULL
    )
}

# S3 Methods for server list display

#' Print method for server_list objects
#'
#' @param x a server_list object
#' @param ... additional arguments (ignored)
#' @export
print.server_list <- function(x, ...) {
    if (length(x) == 0) {
        cat("No running servers\n")
        return(invisible(x))
    }

    cat(sprintf(
        "goServeR: %d running server%s\n",
        length(x),
        if (length(x) == 1) "" else "s"
    ))
    cat(paste(rep("-", 30), collapse = ""), "\n")

    for (i in seq_along(x)) {
        print(x[[i]], index = i)
        if (i < length(x)) cat("\n")
    }

    invisible(x)
}

#' Print method for individual server_info objects
#'
#' @param x a server_info object
#' @param index server index number for display
#' @param ... additional arguments (ignored)
#' @export
print.server_info <- function(x, index = NULL, ...) {
    # Format server header
    if (!is.null(index)) {
        cat(sprintf("Server %d: %s\n", index, x$address))
    } else {
        cat(sprintf("Server: %s\n", x$address))
    }

    # Format details with indentation
    cat(sprintf("  Directory: %s\n", x$directory))
    if (nzchar(x$prefix)) {
        cat(sprintf("  Prefix: %s\n", x$prefix))
    }
    cat(sprintf("  Protocol: %s\n", x$protocol))
    cat(sprintf("  Authentication: %s\n", x$authentication))
    cat(sprintf("  Logging: %s\n", x$logging))

    if (x$logging != "silent") {
        cat(sprintf("  Log Handler: %s\n", x$log_handler))
        cat(sprintf("  Log Destination: %s\n", x$log_destination))
        if (!is.null(x$log_function) && x$log_function != "none") {
            # Truncate long function definitions for readability
            func_display <- x$log_function
            if (nchar(func_display) > 60) {
                func_display <- paste0(substr(func_display, 1, 57), "...")
            }
            cat(sprintf("  Log Function: %s\n", func_display))
        }
    }

    invisible(x)
}

#' Summary method for server_list objects
#'
#' @param object a server_list object
#' @param ... additional arguments (ignored)
#' @export
summary.server_list <- function(object, ...) {
    if (length(object) == 0) {
        cat("No running servers\n")
        return(invisible(object))
    }

    cat(sprintf(
        "goServeR: %d server%s running\n",
        length(object),
        if (length(object) == 1) "" else "s"
    ))
    cat(paste(rep("-", 25), collapse = ""), "\n")

    for (i in seq_along(object)) {
        srv <- object[[i]]
        cat(sprintf(
            "%d. %s (%s) %s\n",
            i,
            srv$address,
            srv$protocol,
            srv$logging
        ))
    }

    invisible(object)
}

#' Convert server list to data frame
#'
#' @param x a server_list object
#' @param ... additional arguments (ignored)
#' @return a data.frame with server information
#' @export
as.data.frame.server_list <- function(x, ...) {
    if (length(x) == 0) {
        return(data.frame())
    }

    do.call(
        rbind,
        lapply(seq_along(x), function(i) {
            srv <- x[[i]]
            data.frame(
                index = i,
                address = srv$address,
                directory = srv$directory,
                protocol = srv$protocol,
                logging = srv$logging,
                log_handler = srv$log_handler,
                log_destination = srv$log_destination,
                log_function = srv$log_function,
                prefix = srv$prefix,
                stringsAsFactors = FALSE
            )
        })
    )
}

#' Add Authentication Key
#'
#' Add an API key to the authentication system
#'
#' @param server_handle External pointer from runServer(blocking=FALSE, auth=TRUE)
#' @param key Character string, the API key to add
#' @return Invisible TRUE
#' @export
addAuthKey <- function(server_handle, key) {
    if (missing(server_handle) || missing(key)) {
        stop("Both server_handle and key are required")
    }

    if (!inherits(server_handle, "externalptr")) {
        stop("Invalid server handle")
    }

    .Call(RC_manage_server_auth, server_handle, key, "ADD")
    invisible(TRUE)
}

#' Remove Authentication Key
#'
#' Remove an API key from the authentication system
#'
#' @param server_handle External pointer from runServer(blocking=FALSE, auth=TRUE)
#' @param key Character string, the API key to remove
#' @return Invisible TRUE
#' @export
removeAuthKey <- function(server_handle, key) {
    if (missing(server_handle) || missing(key)) {
        stop("Both server_handle and key are required")
    }

    if (!inherits(server_handle, "externalptr")) {
        stop("Invalid server handle")
    }

    .Call(RC_manage_server_auth, server_handle, key, "REMOVE")
    invisible(TRUE)
}

#' Clear All Authentication Keys
#'
#' Remove all API keys from the authentication system
#'
#' @param server_handle External pointer from runServer(blocking=FALSE, auth=TRUE)
#' @return Invisible TRUE
#' @export
clearAuthKeys <- function(server_handle) {
    if (missing(server_handle)) {
        stop("server_handle is required")
    }

    if (!inherits(server_handle, "externalptr")) {
        stop("Invalid server handle")
    }

    .Call(RC_manage_server_auth, server_handle, "", "CLEAR")
    invisible(TRUE)
}

#' List Authentication Keys
#'
#' Get all current API keys in the authentication system
#'
#' @param server_handle External pointer from runServer(blocking=FALSE, auth=TRUE)
#' @return Character vector of current API keys
#' @export
listAuthKeys <- function(server_handle) {
    if (missing(server_handle)) {
        stop("server_handle is required")
    }

    if (!inherits(server_handle, "externalptr")) {
        stop("Invalid server handle")
    }

    .Call(RC_list_server_auth_keys, server_handle)
}
