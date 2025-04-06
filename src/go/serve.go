package main

/*
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Visibility.h>
#include <stdlib.h>

// Instead of redefining, we just declare these functions which are defined in C code
int pending_interrupt(void);

// R compatible error handling and printing functions
void Rprintf(const char *, ...);
void REprintf(const char *, ...);
void R_ShowMessage(const char *);
*/
import "C"
import (
	"context"
	"fmt"
	"net/http"
	"path/filepath"
	"time"
)

// Custom logger that uses R's printing functions instead of stdout/stderr
type RLogger struct{}

func (l RLogger) Printf(format string, v ...interface{}) {
	msg := fmt.Sprintf(format, v...)
	C.Rprintf(C.CString(msg))
}

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

	// Create a custom logger that uses R's printing functions
	logger := RLogger{}

	// Create a new ServeMux to avoid conflicts with global handlers
	mux := http.NewServeMux()
	fs := http.FileServer(http.Dir(dir))
	mux.Handle(prefix+"/", corsMiddleware(loggingMiddleware(http.StripPrefix(prefix, fs), logger)))

	// Create server with the new mux
	server := &http.Server{
		Addr:    addr,
		Handler: mux,
	}

	// Create a channel to signal when the server is done
	serverClosed := make(chan struct{})

	// Start the server in a goroutine
	go func() {
		logger.Printf("Starting HTTP server at %s\n", addr)
		logger.Printf("Serving directory: %s\n", dir)
		if prefix != "" {
			logger.Printf("Using prefix: %s\n", prefix)
		}
		if err := server.ListenAndServe(); err != http.ErrServerClosed {
			// Use R's error printing instead of log.Fatalf which calls os.Exit
			C.REprintf(C.CString(fmt.Sprintf("HTTP server error: %v\n", err)))
			close(serverClosed)
		}
	}()

	// Monitor for R interrupts in a loop
	for {
		// Check for interrupt every 300ms (more responsive)
		time.Sleep(300 * time.Millisecond)

		// If interrupt detected, shutdown the server gracefully
		// Call the pending_interrupt function directly
		if int(C.pending_interrupt()) != 0 {
			logger.Printf("\nR interrupt detected, shutting down server...\n")
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()

			if err := server.Shutdown(ctx); err != nil {
				C.REprintf(C.CString(fmt.Sprintf("Error during server shutdown: %v\n", err)))
			}

			// Wait for server to close or timeout
			select {
			case <-serverClosed:
				logger.Printf("Server shutdown complete\n")
			case <-ctx.Done():
				logger.Printf("Server shutdown timed out\n")
			}

			return
		}
	}
}

// loggingMiddleware logs HTTP requests
func loggingMiddleware(next http.Handler, logger RLogger) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		logger.Printf("%s %s %s %s\n", r.Method, r.RequestURI, r.RemoteAddr, time.Since(start))
	})
}

// corsMiddleware adds CORS headers to responses
func corsMiddleware(next http.Handler) http.Handler {
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

func main() {}
