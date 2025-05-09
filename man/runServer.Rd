% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/goServeR.R
\name{runServer}
\alias{runServer}
\title{runServer}
\usage{
runServer(dir = getwd(), addr = "0.0.0.0:8181", prefix = "")
}
\arguments{
\item{dir}{directory to serve}

\item{addr}{address}

\item{prefix}{server prefix}
}
\value{
NULL blocks the session
}
\description{
Run the go http server
}
\examples{
\dontrun{
runServer(dir = ".", addr = "0.0.0.0:8080")
runServer(dir = "/path/to/files", addr = "localhost:8181", prefix = "/api")
}
}
