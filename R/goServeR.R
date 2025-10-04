#' @useDynLib goserveR, .registration = TRUE
NULL

#' runServer
#'
#' Run the go http server (blocking or background)
#'
#' @param dir directory to serve
#' @param addr address
#' @param prefix server prefix
#' @param blocking logical, if FALSE runs in background and returns a handle
#' @param cors logical, enable CORS headers
#' @param coop logical, enable COOP/COEP headers
#' @param tls logical, enable TLS (HTTPS)
#' @param certfile path to TLS certificate file
#' @param keyfile path to TLS key file
#' @param silent logical, suppress server logs
#' @param log_handler function, custom log handler function(handler, message, user)
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
    ...) {
    # Validate input parameters
    stopifnot(
        is.character(dir) && length(dir) == 1 && !is.na(dir) && dir != "",
        dir.exists(dir),
        is.character(addr) && length(addr) == 1 && !is.na(addr),
        grepl("^[^:]+:[0-9]+$", addr), # Check address format (host:port)
        is.character(prefix) && length(prefix) == 1 && !is.na(prefix),
        is.logical(blocking) && length(blocking) == 1,
        is.logical(cors) && length(cors) == 1,
        is.logical(coop) && length(coop) == 1,
        is.logical(tls) && length(tls) == 1,
        is.character(certfile) && length(certfile) == 1,
        is.character(keyfile) && length(keyfile) == 1,
        is.logical(silent) && length(silent) == 1
    )

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

    if (blocking) {
        invisible(.Call(RC_StartServer, dir, addr, prefix, blocking, cors, coop, tls, certfile, keyfile, silent, log_handler))
    } else {
        .Call(RC_StartServer, dir, addr, prefix, blocking, cors, coop, tls, certfile, keyfile, silent, log_handler)
    }
}

#' listServers
#' List all running background servers with detailed information
#' @return a server_list S3 object containing server information
#' @export
listServers <- function() {
    servers <- .Call(RC_list_servers)

    # Format the output for better readability
    if (length(servers) == 0) {
        result <- list()
        class(result) <- "server_list"
        return(result)
    }

    # Add names to make the output more readable
    formatted_servers <- lapply(seq_along(servers), function(i) {
        server_info <- servers[[i]]
        names(server_info) <- c("directory", "address", "prefix", "protocol", "logging", "log_handler", "log_destination", "log_function")

        # Enhance log handler and destination information
        log_handler_type <- as.character(server_info[6])
        log_destination <- as.character(server_info[7])
        log_function_info <- as.character(server_info[8])

        # For file loggers, try to get more specific information
        if (log_handler_type == "file_logger" && log_destination %in% c("custom_file", "custom")) {
            log_destination <- "file (path in closure)"
        }

        # Create a more readable format
        structure(list(
            directory = as.character(server_info[1]),
            address = as.character(server_info[2]),
            prefix = as.character(server_info[3]),
            protocol = as.character(server_info[4]),
            logging = as.character(server_info[5]),
            log_handler = log_handler_type,
            log_destination = log_destination,
            log_function = log_function_info
        ), class = "server_info")
    })

    # Set class for the list
    class(formatted_servers) <- "server_list"
    return(formatted_servers)
}

#' shutdownServer
#' Shutdown a background server
#' @param handle external pointer returned by runServer(blocking=FALSE)
#' @export
shutdownServer <- function(handle) {
    invisible(.Call(RC_shutdown_server, handle))
}

#' StartServer (advanced/manual use)
#' Start a server (C-level, advanced)
#' @param dir directory to serve
#' @param addr address
#' @param prefix server prefix
#' @param blocking logical, if FALSE runs in background and returns a handle
#' @param cors logical, enable CORS headers
#' @param coop logical, enable COOP/COEP headers
#' @param tls logical, enable TLS (HTTPS)
#' @param certfile path to TLS certificate file
#' @param keyfile path to TLS key file
#' @param silent logical, suppress server logs
#' @param log_handler function, custom log handler function(handler, message, user)
#' @export
StartServer <- function(dir, addr, prefix, blocking, cors = FALSE, coop = FALSE, tls = FALSE, certfile = "cert.pem", keyfile = "key.pem", silent = FALSE, log_handler = NULL) {
    .Call(RC_StartServer, dir, addr, prefix, blocking, cors, coop, tls, certfile, keyfile, silent, log_handler)
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
.default_log_callback <- function(handler, message, user) {
    cat("[goserveR]", message)
    flush.console()
}

#' Create file log handler
#'
#' @param fd file descriptor for log pipe
#' @param logfile path to log file
#' @return external pointer to log handler
#' @export
createFileLogHandler <- function(fd, logfile = tempfile("goserveR_", fileext = ".log")) {
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
    registerLogHandler(fd, function(handler, message, user) {
        # Do nothing - silent handler
    }, NULL)
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
        length(x), if (length(x) == 1) "" else "s"
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
        length(object), if (length(object) == 1) "" else "s"
    ))
    cat(paste(rep("-", 25), collapse = ""), "\n")

    for (i in seq_along(object)) {
        srv <- object[[i]]
        cat(sprintf(
            "%d. %s (%s) %s\n",
            i, srv$address, srv$protocol, srv$logging
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

    do.call(rbind, lapply(seq_along(x), function(i) {
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
    }))
}
