/*
 *  background.c - asynchronous log callback into R based on FD activity
 *  Adapted from Simon Urbanek's async.c for goserveR log handling
 *  Copyright (C) 2012,2022 Simon Urbanek
 *  Modified for goserveR by Sounkou Mahammane Toure
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; version 2 of the License
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#define USE_RINTERNALS 1
#include <Rinternals.h>
#include <R_ext/Visibility.h>
#include <R_ext/Boolean.h>

#define BackgroundActivity 10

#ifndef WIN32
#include <R_ext/eventloop.h>
#include <sys/types.h>
#include <unistd.h>
#include <pthread.h>
#else
#include <windows.h>
#include <io.h>  /* for _read, _write, _close */
#endif

static int in_process;

typedef struct bg_log_handler {
    struct bg_log_handler *next, *prev;
    int fd;
    SEXP callback;
    SEXP user;
    SEXP self;
#ifdef WIN32
    struct bg_log_message *msg_head;
    struct bg_log_message *msg_tail;
    HANDLE thread;       /* worker thread */
    CRITICAL_SECTION msg_cs;
    int msg_cs_init;
#else
    InputHandler *ih;    /* worker input handler */
#endif
} bg_log_handler_t;

#ifdef WIN32
typedef struct bg_log_message {
    struct bg_log_message *next;
    char *text;
} bg_log_message_t;
#endif

static bg_log_handler_t *log_handlers;

#ifndef WIN32
static pthread_mutex_t log_handler_mutex = PTHREAD_MUTEX_INITIALIZER;
#define LOCK_LOG_HANDLERS() pthread_mutex_lock(&log_handler_mutex)
#define UNLOCK_LOG_HANDLERS() pthread_mutex_unlock(&log_handler_mutex)
#else
static CRITICAL_SECTION log_handler_cs;
static int log_handler_cs_init = 0;
#define LOCK_LOG_HANDLERS() do { if (!log_handler_cs_init) { InitializeCriticalSection(&log_handler_cs); log_handler_cs_init = 1; } EnterCriticalSection(&log_handler_cs); } while(0)
#define UNLOCK_LOG_HANDLERS() LeaveCriticalSection(&log_handler_cs)
#endif

#ifdef WIN32
#define WM_LOG_CALLBACK ( WM_USER + 1 )
static HWND message_window;
static LRESULT CALLBACK BackgroundWindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
#ifndef HWND_MESSAGE
#define HWND_MESSAGE ((HWND)-3)
#endif
#endif

static int needs_init = 1;

static void first_init()
{
#ifdef WIN32
    HINSTANCE instance = GetModuleHandle(NULL);
    LPCTSTR class = "goserveR_log";
    WNDCLASS wndclass = { 0, BackgroundWindowProc, 0, 0, instance, NULL, 0, 0, NULL, class };
    RegisterClass(&wndclass);
    message_window = CreateWindow(class, "goserveR_log", 0, 1, 1, 1, 1,
                                  HWND_MESSAGE, NULL, instance, NULL);
#endif
    needs_init = 0;
}

static void finalize_log_handler(bg_log_handler_t *h)
{
#ifndef WIN32
    if (h->ih) {
        // Remove from input handlers list first to prevent further callbacks
        removeInputHandler(&R_InputHandlers, h->ih);
        h->ih = NULL;
    }
#else
    // Clean up Windows thread if needed
    if (h->thread) {
        DWORD ts = 0;
        if (GetExitCodeThread(h->thread, &ts) && ts == STILL_ACTIVE) {
            TerminateThread(h->thread, 0);
        }
        CloseHandle(h->thread);
        h->thread = NULL;
    }
    if (h->msg_cs_init) {
        bg_log_message_t *msg;

        EnterCriticalSection(&h->msg_cs);
        msg = h->msg_head;
        h->msg_head = NULL;
        h->msg_tail = NULL;
        LeaveCriticalSection(&h->msg_cs);

        while (msg) {
            bg_log_message_t *next = msg->next;
            free(msg->text);
            free(msg);
            msg = next;
        }

        DeleteCriticalSection(&h->msg_cs);
        h->msg_cs_init = 0;
    }
#endif
    
    // Mark FD as invalid to prevent further reads
    if (h->fd >= 0) {
        h->fd = -1;
    }
    
    LOCK_LOG_HANDLERS();
    if (h->prev) {
        h->prev->next = h->next;
        if (h->next) h->next->prev = h->prev;
    } else if (h->next)
        h->next->prev = 0;
    if (log_handlers == h)
        log_handlers = h->next;
    UNLOCK_LOG_HANDLERS();
    
    if (h->callback != R_NilValue)
        R_ReleaseObject(h->callback);
    if (h->user != R_NilValue)
        R_ReleaseObject(h->user);
    R_ReleaseObject(h->self);
}

#ifdef WIN32
static void run_log_callback_main_thread(bg_log_handler_t *h);

static void run_log_callback(bg_log_handler_t *h)
{
    SendMessage(message_window, WM_LOG_CALLBACK, 0, (LPARAM) h);
}
#define run_log_callback run_log_callback_main_thread
#endif

/* process a log message by calling the callback in R */
static void run_log_callback_(void *ptr)
{
    bg_log_handler_t *h = (bg_log_handler_t*) ptr;
    
    // Check if handler is still valid
    if (!h || h->fd < 0) return;
    
    // Read available data from the pipe
    char buffer[4096];
    ssize_t bytes_read;
    
#ifndef WIN32
    bytes_read = read(h->fd, buffer, sizeof(buffer) - 1);
#else
    bg_log_message_t *msg;

    EnterCriticalSection(&h->msg_cs);
    msg = h->msg_head;
    if (!msg) {
        LeaveCriticalSection(&h->msg_cs);
        return;
    }
    h->msg_head = msg->next;
    if (!h->msg_head) {
        h->msg_tail = NULL;
    }
    LeaveCriticalSection(&h->msg_cs);

    strncpy(buffer, msg->text, sizeof(buffer) - 1);
    buffer[sizeof(buffer) - 1] = '\0';
    bytes_read = (ssize_t) strlen(buffer);
    free(msg->text);
    free(msg);
#endif
    
    // Check for read errors or closed pipe
    if (bytes_read <= 0) {
        // Pipe was closed or error occurred - remove this handler
#ifndef WIN32
        if (h->ih) {
            removeInputHandler(&R_InputHandlers, h->ih);
            h->ih = NULL;
        }
#endif
        return;
    }
    
    buffer[bytes_read] = '\0';
    
    // Create R string from the log message
    SEXP log_msg = PROTECT(mkString(buffer));
    SEXP what = PROTECT(lang4(h->callback, h->self, log_msg, h->user));
    
    // Use tryCatch-like mechanism to handle errors in the callback
    SEXP result = R_tryEval(what, R_GlobalEnv, NULL);
    if (result == NULL) {
        // Error occurred in callback - just ignore it to prevent recursive errors
        // We could log this to stderr, but that would defeat the purpose
        // of eliminating stderr usage for CRAN compliance
    }
    
    UNPROTECT(2);
}

/* wrap the actual call with ToplevelExec */
static void run_log_callback(bg_log_handler_t *h)
{
    if (in_process) return;
    in_process = 1;
    R_ToplevelExec(run_log_callback_, h);
    in_process = 0;
}

#ifdef WIN32
#undef run_log_callback
#endif

#ifndef WIN32
static void log_input_handler(void *data);
#endif

#ifdef WIN32
static LRESULT CALLBACK BackgroundWindowProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    if (hwnd == message_window && uMsg == WM_LOG_CALLBACK) {
        bg_log_handler_t *h = (bg_log_handler_t*) lParam;
        run_log_callback_main_thread(h);
        return 0;
    }
    return DefWindowProc(hwnd, uMsg, wParam, lParam);
}

static DWORD WINAPI LogThreadProc(LPVOID lpParameter) {
    bg_log_handler_t *h = (bg_log_handler_t*) lpParameter;
    char buffer[4096];
    int bytes_read;

    if (!h) return 0;

    for (;;) {
        if (h->fd < 0) {
            break;
        }

        bytes_read = _read(h->fd, buffer, sizeof(buffer) - 1);
        if (bytes_read <= 0) {
            break;
        }

        buffer[bytes_read] = '\0';

        bg_log_message_t *msg = (bg_log_message_t*) calloc(1, sizeof(bg_log_message_t));
        if (!msg) {
            break;
        }
        msg->text = (char*) calloc((size_t) bytes_read + 1, sizeof(char));
        if (!msg->text) {
            free(msg);
            break;
        }
        memcpy(msg->text, buffer, (size_t) bytes_read + 1);

        EnterCriticalSection(&h->msg_cs);
        if (h->msg_tail) {
            h->msg_tail->next = msg;
        } else {
            h->msg_head = msg;
        }
        h->msg_tail = msg;
        LeaveCriticalSection(&h->msg_cs);

        if (!PostMessage(message_window, WM_LOG_CALLBACK, 0, (LPARAM) h)) {
            EnterCriticalSection(&h->msg_cs);
            if (h->msg_head == msg) {
                h->msg_head = msg->next;
            } else {
                bg_log_message_t *cur = h->msg_head;
                while (cur && cur->next != msg) cur = cur->next;
                if (cur) cur->next = msg->next;
            }
            if (h->msg_tail == msg) {
                h->msg_tail = NULL;
            }
            LeaveCriticalSection(&h->msg_cs);
            free(msg->text);
            free(msg);
            break;
        }
    }

    return 0;
}
#endif

#ifndef WIN32
static void log_input_handler(void *data)
{
    run_log_callback((bg_log_handler_t*) data);
}
#endif

/* Register a log handler for a file descriptor */
SEXP register_log_handler(SEXP s_fd, SEXP callback, SEXP user)
{
    int fd = Rf_asInteger(s_fd);
    bg_log_handler_t *h;

    if (needs_init)
        first_init();

    h = (bg_log_handler_t*) calloc(1, sizeof(bg_log_handler_t));
    if (!h)
        Rf_error("out of memory");

    LOCK_LOG_HANDLERS();
    if (log_handlers) {
        h->next = log_handlers;
        if (log_handlers) log_handlers->prev = h;
    }
    log_handlers = h;
    UNLOCK_LOG_HANDLERS();
    
    h->fd = fd;
    h->callback = callback;
    R_PreserveObject(callback);
    h->user = user;
    if (user != R_NilValue)
        R_PreserveObject(user);
    R_PreserveObject(h->self = R_MakeExternalPtr(h, R_NilValue, R_NilValue));
    Rf_setAttrib(h->self, Rf_install("class"), mkString("LogHandler"));
    
#ifndef WIN32
    h->ih = addInputHandler(R_InputHandlers, fd, &log_input_handler, BackgroundActivity);
    if (h->ih) h->ih->userData = h;
#else
    InitializeCriticalSection(&h->msg_cs);
    h->msg_cs_init = 1;
    h->msg_head = NULL;
    h->msg_tail = NULL;
    h->thread = CreateThread(NULL, 0, LogThreadProc, (LPVOID) h, 0, 0);
#endif
    return h->self;
}

/* Remove a log handler */
SEXP remove_log_handler(SEXP h_ptr) {
    bg_log_handler_t *h;
    if (TYPEOF(h_ptr) != EXTPTRSXP || !inherits(h_ptr, "LogHandler"))
        Rf_error("invalid log handler");
    h = (bg_log_handler_t*) R_ExternalPtrAddr(h_ptr);
    if (!h) return ScalarLogical(0);
    
    finalize_log_handler(h);
    free(h);
    R_ClearExternalPtr(h_ptr);
    return ScalarLogical(1);
}

/* Finalizer for log handlers */
void log_handler_finalizer(SEXP h_ptr) {
    bg_log_handler_t *h = (bg_log_handler_t*) R_ExternalPtrAddr(h_ptr);
    if (!h) return;
    finalize_log_handler(h);
    free(h);
    R_ClearExternalPtr(h_ptr);
}

#ifndef WIN32
/* read one byte from a FD; returns -1 on close/error */
SEXP read_from_fd(SEXP s_fd) {
    unsigned char b;
    int fd = Rf_asInteger(s_fd);
    if (read(fd, &b, 1) < 1) {
        close(fd);
        return ScalarInteger(-1);
    }
    return ScalarInteger((int)b);
}
#endif

#if 0 /* just a reminder how to stop the thread if needed */
#ifdef WIN32
    if (c->thread) {
	DWORD ts = 0;
	if (GetExitCodeThread(c->thread, &ts) && ts == STILL_ACTIVE)
	    TerminateThread(c->thread, 0);
    }
#endif
#endif
