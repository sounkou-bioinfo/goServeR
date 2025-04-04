package main

/*
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Visibility.h>
#include <stdlib.h> 

// Instead of redefining, we just declare these functions which are defined in C code
int pending_interrupt(void);
*/
import "C"
import (
	"context"
	"fmt"
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

	// Create a new ServeMux to avoid conflicts with global handlers
	mux := http.NewServeMux()
	fs := http.FileServer(http.Dir(dir))
	mux.Handle(prefix+"/", corsMiddleware(loggingMiddleware(http.StripPrefix(prefix, fs))))

	// Create server with the new mux
	server := &http.Server{
		Addr:    addr,
		Handler: mux,
	}
	
	// Create a channel to signal when the server is done
	serverClosed := make(chan struct{})
	
	// Start the server in a goroutine
	go func() {
		fmt.Printf("Starting HTTP server at %s\n", addr)
		fmt.Printf("Serving directory: %s\n", dir)
		if prefix != "" {
			fmt.Printf("Using prefix: %s\n", prefix)
		}
		if err := server.ListenAndServe(); err != http.ErrServerClosed {
			log.Fatalf("HTTP server error: %v", err)
		}
		close(serverClosed)
	}()
	
	// Monitor for R interrupts in a loop
	for {
		// Check for interrupt every 300ms (more responsive)
		time.Sleep(300 * time.Millisecond)
		
		// If interrupt detected, shutdown the server gracefully
		// Call the pending_interrupt function directly
		if int(C.pending_interrupt()) != 0 {
			fmt.Println("\nR interrupt detected, shutting down server...")
			ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
			defer cancel()
			
			if err := server.Shutdown(ctx); err != nil {
				log.Printf("Error during server shutdown: %v", err)
			}
			
			// Wait for server to close or timeout
			select {
			case <-serverClosed:
				fmt.Println("Server shutdown complete")
			case <-ctx.Done():
				fmt.Println("Server shutdown timed out")
			}
			
			return
		}
	}
}

// loggingMiddleware logs HTTP requests
func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("%s %s %s %s", r.Method, r.RequestURI, r.RemoteAddr, time.Since(start))
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

//export StartServer
func StartServer(port C.int) *C.char {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello from Go server!")
	})
	
	portStr := fmt.Sprintf(":%d", int(port))
	go func() {
		http.ListenAndServe(portStr, nil)
	}()
	
	return C.CString(fmt.Sprintf("Server started on port %d", int(port)))
}

func main() {}