# goserveR NEWS

## goserveR 0.1.3-0.90000 (development)

- Dynamic authentication management functions (`addAuthKey()`, `removeAuthKey()`, `listAuthKeys()`) now work with the new server-based auth system.
- removed unsafe pointer arithmetic in Go.
- Changed cph

## goserveR 0.1.3

- **MAJOR**: Added support for serving multiple directories from a single server instance. The `dir` and `prefix` parameters now accept character vectors of the same length, allowing one server to serve different directories at different URL prefixes.
- **BREAKING CHANGE**: `dir` and `prefix` parameters now accept vectors instead of just single values (backward compatible for single values).
- Enhanced server logging to show all registered directory/prefix pairs during startup.
- Updated server listing to display multiple directories and prefixes in a comma-separated format.
- Improved memory management for handling multiple directory/prefix arrays in C code.
- Updated documentation with comprehensive examples of multiple directory serving.
- All existing functionality remains backward compatible.

## goserveR 0.1.2-0.92000

- **NEW**: Added API key authentication support via `auth_keys` parameter in `runServer()`. Users can now secure their file servers with API key authentication using the `X-API-Key` header.
- Authentication can be combined with TLS for secure, authenticated HTTPS file serving.
- Enhanced security features for production-ready deployments.
- Updated documentation with comprehensive authentication examples.
- All authentication functionality is thoroughly tested and documented.

## goserveR 0.1.2-0.91000

- **NEW**: Added custom log handler support via `log_handler` parameter in `runServer()`. Users can now provide custom functions to process server logs (e.g., file logging, custom formatting).
- Fixed race conditions in background log handlers that could cause test hanging during server shutdown.
- Improved thread-safe coordination between server shutdown and async log handler cleanup.
- Enhanced error handling in log callback functions to prevent cascading failures.
- Added proper input handler removal during server finalization to prevent reading from closed pipes.
- All tests now pass reliably without hanging issues during concurrent server operations.
- Added comprehensive tests for custom log handler functionality.

## goserveR 0.1.2

- Serve files and directories at the correct URL paths by default (root or prefix), matching standard Go FileServer behavior.
- Directory listing is enabled by default if no index.html is present.
- Always use the absolute path for the served directory at the Go level for robust file serving and logging.
- TLS (`tls=TRUE`) now reliably enables HTTPS; usage and documentation clarified.
- Range requests and CORS remain fully supported.
- All tinytest tests pass after these changes.

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
