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
    blocking = TRUE) {
    # Validate input parameters
    stopifnot(
        is.character(dir) && length(dir) == 1 && !is.na(dir) && dir != "",
        dir.exists(dir),
        is.character(addr) && length(addr) == 1 && !is.na(addr),
        grepl("^[^:]+:[0-9]+$", addr), # Check address format (host:port)
        is.character(prefix) && length(prefix) == 1 && !is.na(prefix),
        is.logical(blocking) && length(blocking) == 1
    )

    dir <- normalizePath(dir)
    if (blocking) {
        invisible(.Call(RC_StartServer, dir, addr, prefix, TRUE))
    } else {
        .Call(RC_StartServer, dir, addr, prefix, FALSE)
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
#' @export
StartServer <- function(dir, addr, prefix, blocking) {
    .Call(RC_StartServer, dir, addr, prefix, blocking)
}
