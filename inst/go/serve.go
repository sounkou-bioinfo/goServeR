package main
/*
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Visibility.h>
#include <stdlib.h> 
//interupt 
// ref : https://github.com/cran/curl/blob/master/src/interrupt.c
// https://stackoverflow.com/questions/40563522/r-how-to-write-interruptible-c-function-and-recover-partial-results
void check_interrupt_fn(void *dummy) {
  R_CheckUserInterrupt();
}
//
int pending_interrupt(void) {
  return !(R_ToplevelExec(check_interrupt_fn, NULL));
}

typedef int (*R_interupt_fun) (void); 

int bridge_interupter( R_interupt_fun f) {
  return f();
}
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
    f_Rinterupt := C.R_interupt_fun(C.pending_interrupt)
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
        fmt.Println(int(C.bridge_interupter(f_Rinterupt)))
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
