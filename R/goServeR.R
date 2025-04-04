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
#' # ADD_EXAMPLES_HERE
#' }
runServer <- function(dir = getwd(), addr = "0.0.0.0:8181", prefix = "") {
    # TO : add asserts
    stopifnot(
        dir.exists(dir)
    )
    dir <- normalizePath(dir)
    print(dir)
    print(addr)
    .Call("run_server", as.character(dir), as.character(addr), as.character(prefix))
}
