#' @useDynLib goserveR, .registration = TRUE
NULL

#' runServer
#'
#' Run the go http server
#'
#' @param dir directory to serve
#' @param addr address
#' @param prefix server prefix
#'
#' @return NULL blocks the session
#' @export
#' @examples
#' \dontrun{
#' runServer(dir = ".", addr = "0.0.0.0:8080")
#' runServer(dir = "/path/to/files", addr = "localhost:8181", prefix = "/api")
#' }
runServer <- function(dir = getwd(), addr = "0.0.0.0:8181", prefix = "") {
    # Validate input parameters
    stopifnot(
        is.character(dir) && length(dir) == 1 && !is.na(dir) && dir != "",
        dir.exists(dir),
        is.character(addr) && length(addr) == 1 && !is.na(addr),
        grepl("^[^:]+:[0-9]+$", addr), # Check address format (host:port)
        is.character(prefix) && length(prefix) == 1 && !is.na(prefix)
    )

    dir <- normalizePath(dir)
    message("Starting server...")
    message("Directory: ", dir)
    message("Address: http://", addr)
    if (prefix != "") message("Prefix: ", prefix)
    message("Press Ctrl+C to stop the server")

    .Call(run_server, as.character(dir), as.character(addr), as.character(prefix))
}
