//go:build ignore
// +build ignore

// Server implementation.
// Inspired by Eli Bendersky [https://eli.thegreenplace.net]
// This code is in the public domain.
// Contributor: Eli Bendersky (inspiration)

package main

/*
#include <stdlib.h>
*/
import "C"
import (
	"context"
	"crypto/tls"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"time"
)

//export RunServerWithShutdown
func RunServerWithShutdown(cDir *C.char, cAddr *C.char, cPrefix *C.char, cCors, cCoop, cTls, cSilent C.int, cCertFile, cKeyFile *C.char, shutdownFd C.int) {
	dir := C.GoString(cDir)
	addr := C.GoString(cAddr)
	prefix := C.GoString(cPrefix)
	certFile := C.GoString(cCertFile)
	keyFile := C.GoString(cKeyFile)
	cors := cCors != 0
	coop := cCoop != 0
	useTLS := cTls != 0 // renamed from tls to avoid shadowing
	silent := cSilent != 0

	if dir == "" {
		dir = "."
	}
	if addr == "" {
		addr = "0.0.0.0:8080"
	}
	if prefix == "" {
		prefix = "/"
	}

	serveLog := log.New(os.Stdout, "", log.LstdFlags|log.Lmicroseconds)
	if silent {
		serveLog.SetOutput(io.Discard)
	}

	mux := http.NewServeMux()
	fileHandler := serveLogger(serveLog, http.FileServer(http.Dir(dir)))
	if cors {
		fileHandler = enableCORS(fileHandler)
	}
	if coop {
		fileHandler = enableCOOP(fileHandler)
	}
	mux.Handle(prefix, fileHandler)

	srv := &http.Server{
		Addr:    addr,
		Handler: mux,
	}
	if useTLS {
		srv.TLSConfig = &tls.Config{
			MinVersion:               tls.VersionTLS12,
			PreferServerCipherSuites: true,
		}
	}

	serverClosed := make(chan struct{})
	go func() {
		if useTLS {
			serveLog.Printf("Serving directory %q on https://%v", dir, addr)
			if err := srv.ListenAndServeTLS(certFile, keyFile); err != http.ErrServerClosed {
				log.Fatalf("HTTPS server error: %v", err)
			}
		} else {
			serveLog.Printf("Serving directory %q on http://%v", dir, addr)
			if err := srv.ListenAndServe(); err != http.ErrServerClosed {
				log.Fatalf("HTTP server error: %v", err)
			}
		}
		close(serverClosed)
	}()

	// Wait for shutdown signal on the pipe
	buf := make([]byte, 1)
	shutdownFile := os.NewFile(uintptr(shutdownFd), "shutdown-pipe")
	_, _ = shutdownFile.Read(buf) // blocks until shutdown
	fmt.Printf("Shutdown signal received—shutting down HTTP server at %s (prefix: %s)\n", addr, prefix)
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	_ = srv.Shutdown(ctx)
	<-serverClosed
}

// serveLogger logs HTTP requests to the given logger
func serveLogger(logger *log.Logger, next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		logger.Printf("%s %s %s %s", r.Method, r.RequestURI, r.RemoteAddr, time.Since(start))
	})
}

// enableCORS enables Cross-Origin Resource Sharing (CORS) for the given handler
func enableCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, Range")
		w.Header().Set("Access-Control-Expose-Headers", "Content-Length, Content-Range, Accept-Ranges")

		if r.Method == "OPTIONS" {
			w.WriteHeader(http.StatusOK)
			return
		}
		next.ServeHTTP(w, r)
	})
}

// enableCOOP enables Cross-Origin-Opener-Policy (COOP) for the given handler
func enableCOOP(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Cross-Origin-Opener-Policy", "same-origin")
		next.ServeHTTP(w, r)
	})
}

// Only run main when building as a standalone binary, not as a shared library for R
func main() {
	fmt.Println("Standalone mode: no-op main. This is required for c-archive builds but does nothing.")
}
