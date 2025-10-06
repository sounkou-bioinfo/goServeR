//go:build ignore
// +build ignore

// Server implementation.
// Inspired by Eli Bendersky [https://eli.thegreenplace.net]
// This code is in the public domain.
// Contributor: Eli Bendersky (inspiration)

// NOTE: CRAN check warnings about 'abort' and 'stderr' in compiled code:
// These come from the Go runtime standard library, not from user code.
// The Go HTTP server runs in a separate thread and all R session control
// remains in C code. Go errors are handled gracefully without terminating R.

package main

/*
#include <stdlib.h>
*/
import "C"
import (
	"bufio"
	"context"
	"crypto/tls"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
	"unsafe"
)

//export RunServerWithLogging
func RunServerWithLogging(cDirs **C.char, cAddr *C.char, cPrefixes **C.char, cNumPaths C.int, cCors, cCoop, cTls, cSilent C.int, cCertFile, cKeyFile *C.char, shutdownFd, logFd C.int, cAuthKeys *C.char, authPipeFd C.int) {
	addr := C.GoString(cAddr)
	certFile := C.GoString(cCertFile)
	keyFile := C.GoString(cKeyFile)
	authKeys := C.GoString(cAuthKeys) // NEW: Auth keys (comma-separated or empty)
	cors := cCors != 0
	coop := cCoop != 0
	useTLS := cTls != 0
	silent := cSilent != 0
	numPaths := int(cNumPaths)

	// Create per-server auth manager (not global!)
	var serverAuth *PipeAuthManager
	if authPipeFd >= 0 {
		serverAuth = NewPipeAuthManager(int(authPipeFd))
	}

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

		// Add auth middleware if auth keys are provided or auth pipe exists
		if authKeys != "" || serverAuth != nil {
			fileHandler = authMiddleware(fileHandler, authKeys, serveLog, serverAuth)
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

	// Clean up per-server auth (not global!)
	if serverAuth != nil {
		serverAuth.close()
	}
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

// authMiddleware adds pipe-based authentication
func authMiddleware(next http.Handler, validKeys string, logger *log.Logger, pipeAuth *PipeAuthManager) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// Check auth key in header or query parameter
		authKey := r.Header.Get("X-API-Key")
		if authKey == "" {
			authKey = r.URL.Query().Get("api_key")
		}

		// If no pipe auth manager and no static keys, allow access (no auth)
		if pipeAuth == nil && validKeys == "" {
			next.ServeHTTP(w, r)
			return
		}

		// Check pipe-based auth first (if available)
		if pipeAuth != nil && authKey != "" && pipeAuth.isValidKey(authKey) {
			logger.Printf("Auth granted (pipe) from %s for %s", r.RemoteAddr, r.RequestURI)
			next.ServeHTTP(w, r)
			return
		}

		// Fall back to static keys (backward compatibility)
		if validKeys != "" && authKey != "" {
			for _, validKey := range strings.Split(validKeys, ",") {
				if strings.TrimSpace(validKey) == authKey {
					logger.Printf("Auth granted (static) from %s for %s", r.RemoteAddr, r.RequestURI)
					next.ServeHTTP(w, r)
					return
				}
			}
		}

		logger.Printf("Auth denied - invalid key from %s for %s", r.RemoteAddr, r.RequestURI)
		http.Error(w, "Unauthorized", http.StatusUnauthorized)
	})
}

// Pipe-based authentication manager
type PipeAuthManager struct {
	keys     map[string]bool
	mutex    sync.RWMutex
	authPipe *os.File
	done     chan bool
}

func NewPipeAuthManager(pipeFd int) *PipeAuthManager {
	if pipeFd < 0 {
		return nil // No pipe auth
	}

	pam := &PipeAuthManager{
		keys:     make(map[string]bool),
		done:     make(chan bool),
		authPipe: os.NewFile(uintptr(pipeFd), "auth_pipe"),
	}

	go pam.listenForCommands()
	return pam
}

func (pam *PipeAuthManager) listenForCommands() {
	if pam.authPipe == nil {
		return
	}

	scanner := bufio.NewScanner(pam.authPipe)
	for scanner.Scan() {
		select {
		case <-pam.done:
			return
		default:
			cmd := strings.TrimSpace(scanner.Text())
			pam.processCommand(cmd)
		}
	}
}

func (pam *PipeAuthManager) processCommand(cmd string) {
	parts := strings.SplitN(cmd, ":", 2)
	if len(parts) != 2 {
		return
	}

	action, key := parts[0], parts[1]

	pam.mutex.Lock()
	defer pam.mutex.Unlock()

	switch action {
	case "ADD":
		pam.keys[key] = true
	case "REMOVE":
		delete(pam.keys, key)
	case "CLEAR":
		pam.keys = make(map[string]bool)
	}
}

func (pam *PipeAuthManager) isValidKey(key string) bool {
	if pam == nil {
		return false
	}
	pam.mutex.RLock()
	defer pam.mutex.RUnlock()
	return pam.keys[key]
}

func (pam *PipeAuthManager) close() {
	if pam != nil {
		close(pam.done)
		if pam.authPipe != nil {
			pam.authPipe.Close()
		}
	}
}

// Only run main when building as a standalone binary, not as a shared library for R
func main() {
}
