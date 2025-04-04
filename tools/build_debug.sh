#!/bin/bash
# Debug script for building the Go components

set -e
cd $(dirname "$0")/..

echo "=== Environment ==="
echo "R_HOME: $R_HOME"
echo "Go version: $(go version)"
echo "R version: $(R --version | head -1)"
echo "Working directory: $(pwd)"

echo -e "\n=== R Include Paths ==="
R_INC=$(R CMD config --cppflags)
echo "R CPPFLAGS: $R_INC"

echo -e "\n=== Building Go library ==="
cd src/go
echo "Go directory: $(pwd)"

# Create go.mod if it doesn't exist
if [ ! -f go.mod ]; then
    echo "Creating go.mod..."
    echo "module github.com/sounkou-bioinfo/goServeR" > go.mod
    echo "go 1.17" >> go.mod
fi

echo "Building with CGO_CFLAGS=$R_INC"
export CGO_CFLAGS="$R_INC"
go build -x -v -o ../serve.a -buildmode=c-archive serve.go

echo -e "\n=== Build complete ==="
if [ -f ../serve.a ]; then
    echo "Library built successfully: $(ls -la ../serve.a)"
else
    echo "Build failed: library not found"
    exit 1
fi
