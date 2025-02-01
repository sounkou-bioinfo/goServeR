package main

/*
#include <stdlib.h>
*/
import "C"
import (
    "log"
    "net/http"
    "path/filepath"
    "time"
)

//export RunServer
func RunServer(cDir *C.char, cAddr *C.char, cPrefix *C.char) {
    dir := C.GoString(cDir)
    addr := C.GoString(cAddr)
    prefix := C.GoString(cPrefix)

    // Set default values if dir or addr are empty
    if dir == "" {
        dir = "."
    }
    if addr == "" {
        addr = "0.0.0.0:8080"
    }

    // Clean and use the full path as the prefix if prefix is empty
    if prefix == "" {
        prefix = filepath.Clean(dir)
    }

    fs := http.FileServer(http.Dir(dir))
    http.Handle(prefix+"/", corsMiddleware(loggingMiddleware(http.StripPrefix(prefix, fs))))

    server := &http.Server{
        Addr: addr,
    }
    log.Fatal(server.ListenAndServe())
}

func loggingMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        start := time.Now()
        next.ServeHTTP(w, r)
        log.Printf("%s %s %s %s", r.Method, r.RequestURI, r.RemoteAddr, time.Since(start))
    })
}

func corsMiddleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        w.Header().Set("Access-Control-Allow-Origin", "*")
        w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
        w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
        if r.Method == "OPTIONS" {
            w.WriteHeader(http.StatusOK)
            return
        }
        next.ServeHTTP(w, r)
    })
}

func main() {}