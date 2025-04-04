# Helper functions for goServeR tests

# Function to start server in background and return a handle to kill it
start_test_server <- function(dir = getwd(), addr = "127.0.0.1:8181", prefix = "") {
    # Start the server in a separate R process
    if (!dir.exists(dir)) {
        dir.create(dir, recursive = TRUE)
    }

    # Create a temporary script to run the server
    script_file <- tempfile(fileext = ".R")
    cat(sprintf(
        'library(goserveR); goserveR::runServer(dir = "%s", addr = "%s", prefix = "%s")',
        dir, addr, prefix
    ), file = script_file)

    # Get the host and port from the addr
    parts <- strsplit(addr, ":")[[1]]
    host <- parts[1]
    port <- as.integer(parts[2])

    # Start the R process
    process <- sys::r_background(
        c("-f", script_file),
        std_out = FALSE,
        std_err = FALSE
    )

    # Wait a bit for the server to start
    Sys.sleep(1)

    # Return a list with the process and connection info
    list(
        process = process,
        host = host,
        port = port,
        kill = function() {
            process$kill()
            Sys.sleep(0.5) # Give it time to shut down
        }
    )
}

# Function to make HTTP requests to the test server
make_test_request <- function(server, path = "/", method = "GET") {
    url <- sprintf("http://%s:%d%s", server$host, server$port, path)

    # Only require httr if we're actually running this test
    if (!requireNamespace("httr", quietly = TRUE)) {
        stop("Package 'httr' needed for this test to work. Please install it.")
    }

    result <- try(
        {
            response <- httr::VERB(
                method,
                url,
                httr::add_headers(
                    "Origin" = "http://test-origin.example.com"
                )
            )
            response
        },
        silent = TRUE
    )

    if (inherits(result, "try-error")) {
        return(NULL)
    }

    result
}
