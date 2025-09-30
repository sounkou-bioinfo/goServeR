# goserveR NEWS

## goserveR 0.1.1-3.90000
- Interrupt handling is now fully managed at the C level: the Go server runs in a background thread, and the main C thread checks for user interrupts and signals shutdown if needed.
- Improved portability: platform abstraction macros for threading, pipes, and sleep were added to support both UNIX and Windows (RTools) builds.
- All server output and interrupt handling now work robustly in both blocking and background modes.
- Updated documentation to reflect new architecture and usage.

## goserveR 0.1.1
- Bumped version to 0.1.1.
- Initial release of the package with HTTP file server functionality.
- Supports range requests and unbounded CORS.
- Provides an interface to call Go functions from R using cgo.
