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
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"time"
	"unsafe"
)

//export RunServerWithLogging
func RunServerWithLogging(cDirs **C.char, cAddr *C.char, cPrefixes **C.char, cNumPaths C.int, cCors, cCoop, cTls, cSilent C.int, cCertFile, cKeyFile *C.char, shutdownFd, logFd C.int, cAuthKeys *C.char) {
	addr := C.GoString(cAddr)
	certFile := C.GoString(cCertFile)
	keyFile := C.GoString(cKeyFile)
	authKeys := C.GoString(cAuthKeys) // NEW: Auth keys (comma-separated or empty)
	cors := cCors != 0
	coop := cCoop != 0
	useTLS := cTls != 0
	silent := cSilent != 0
	numPaths := int(cNumPaths)

	// Convert C arrays to Go slices
	dirs := make([]string, numPaths)
	prefixes := make([]string, numPaths)

	// Extract directories and prefixes from C arrays
	for i := 0; i < numPaths; i++ {
		// Access array elements using pointer arithmetic
		dirPtr := (**C.char)(unsafe.Pointer(uintptr(unsafe.Pointer(cDirs)) + uintptr(i)*unsafe.Sizeof(*cDirs)))
		prefixPtr := (**C.char)(unsafe.Pointer(uintptr(unsafe.Pointer(cPrefixes)) + uintptr(i)*unsafe.Sizeof(*cPrefixes)))

		dir := C.GoString(*dirPtr)
		prefix := C.GoString(*prefixPtr)

		if dir == "" {
			dir = "."
		}
		absDir, err := filepath.Abs(dir)
		if err != nil {
			absDir = filepath.Clean(dir)
		}
		dirs[i] = absDir

		if prefix == "" {
			prefix = absDir
		}
		prefixes[i] = prefix
	}

	if addr == "" {
		addr = "0.0.0.0:8080"
	}

	// Create logger that writes to the log pipe
	var logWriter io.Writer
	if silent {
		logWriter = io.Discard
	} else {
		logWriter = os.NewFile(uintptr(logFd), "log-pipe")
	}

	serveLog := log.New(logWriter, "", log.LstdFlags|log.Lmicroseconds)

	mux := http.NewServeMux()

	// Register handlers for each directory/prefix pair
	for i := 0; i < numPaths; i++ {
		dir := dirs[i]
		prefix := prefixes[i]

		fileHandler := serveLogger(serveLog, http.FileServer(http.Dir(dir)))

		// Add auth middleware if auth keys are provided
		if authKeys != "" {
			fileHandler = authMiddleware(fileHandler, authKeys, serveLog)
		}

		if cors {
			fileHandler = enableCORS(fileHandler)
		}
		if coop {
			fileHandler = enableCOOP(fileHandler)
		}

		// Handle root prefix "/" properly
		if prefix == "/" {
			mux.Handle("/", fileHandler)
		} else {
			mux.Handle(prefix+"/", http.StripPrefix(prefix, fileHandler))
		}

		serveLog.Printf("Registered handler for directory %q at prefix %q", dir, prefix)
	}

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
		// Wrap server execution with panic recovery
		defer func() {
			if r := recover(); r != nil {
				serveLog.Printf("PANIC: Server panicked: %v", r)
				close(serverClosed)
			}
		}()

		if useTLS {
			serveLog.Printf("Serving %d directories on https://%v", numPaths, addr)
		} else {
			serveLog.Printf("Serving %d directories on http://%v", numPaths, addr)
		}

		if useTLS {
			if err := srv.ListenAndServeTLS(certFile, keyFile); err != http.ErrServerClosed {
				serveLog.Printf("HTTPS server error: %v", err)
				close(serverClosed)
				return
			}
		} else {
			if err := srv.ListenAndServe(); err != http.ErrServerClosed {
				serveLog.Printf("HTTP server error: %v", err)
				close(serverClosed)
				return
			}
		}
		close(serverClosed)
	}()

	// Wait for shutdown signal on the pipe or server error
	buf := make([]byte, 1)
	shutdownFile := os.NewFile(uintptr(shutdownFd), "shutdown-pipe")

	// Use select to wait for either shutdown signal or server closure
	done := make(chan bool)
	go func() {
		_, _ = shutdownFile.Read(buf) // blocks until shutdown signal
		done <- true
	}()

	select {
	case <-done:
		serveLog.Printf("Shutdown signal received—shutting down HTTP server at %s", addr)
	case <-serverClosed:
		serveLog.Printf("Server closed due to error—shutting down HTTP server at %s", addr)
	}

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

// authMiddleware adds simple key-based authentication
func authMiddleware(next http.Handler, validKeys string, logger *log.Logger) http.Handler {
	// Parse comma-separated keys into a map for fast lookup
	keyMap := make(map[string]bool)
	if validKeys != "" {
		for _, key := range strings.Split(validKeys, ",") {
			key = strings.TrimSpace(key)
			if key != "" {
				keyMap[key] = true
			}
		}
	}

	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Check auth key in header or query parameter
		authKey := r.Header.Get("X-API-Key")
		if authKey == "" {
			authKey = r.URL.Query().Get("api_key")
		}

		// If no valid keys configured, allow access (no auth)
		if len(keyMap) == 0 {
			next.ServeHTTP(w, r)
			return
		}

		// Check if provided key is valid
		if authKey == "" || !keyMap[authKey] {
			logger.Printf("Auth denied - invalid key from %s for %s", r.RemoteAddr, r.RequestURI)
			http.Error(w, "Unauthorized", http.StatusUnauthorized)
			return
		}

		logger.Printf("Auth granted from %s for %s", r.RemoteAddr, r.RequestURI)
		next.ServeHTTP(w, r)
	})
}

// Only run main when building as a standalone binary, not as a shared library for R
func main() {}
