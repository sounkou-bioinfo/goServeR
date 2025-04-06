#ifndef _GOSERVER_RSERVE_H_
#define _GOSERVER_RSERVE_H_

#include <R.h>
#include <Rinternals.h>
#include <R_ext/Visibility.h>
#include "serve.h"
#include "interupt.h"

// Go function, this is also available in serve.h
extern void RunServer(char* dir, char* addr, char* prefix);

#endif
