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
#' # Start a server with CORS and COOP enabled
#' h <- runServer(cors = TRUE, coop = TRUE, blocking = FALSE)
#'
#' # List all running background servers
#' listServers()
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

    dir <- normalizePath(dir)
    # If prefix is empty, set it to the normalized absolute path of the served directory
    if (is.character(prefix) && length(prefix) == 1 && (is.na(prefix) || prefix == "")) {
        prefix <- normalizePath(dir)
    }

    if (blocking) {
        invisible(.Call(RC_StartServer, dir, addr, prefix, blocking, cors, coop, tls, certfile, keyfile, silent))
    } else {
        .Call(RC_StartServer, dir, addr, prefix, blocking, cors, coop, tls, certfile, keyfile, silent)
    }
}

#' listServers
#' List all running background servers
#' @return a list of server info
#' @export
listServers <- function() {
    .Call(RC_list_servers)
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
#' @export
StartServer <- function(dir, addr, prefix, blocking, cors = FALSE, coop = FALSE, tls = FALSE, certfile = "cert.pem", keyfile = "key.pem", silent = FALSE) {
    .Call(RC_StartServer, dir, addr, prefix, blocking, cors, coop, tls, certfile, keyfile, silent)
}
