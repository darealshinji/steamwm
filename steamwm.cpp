#ifndef _GNU_SOURCE
#define _GNU_SOURCE
#endif

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
#include <unistd.h>
#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>

#define STR_(x) # x
#define STR(x)  STR_(x)
#define BASE_NAME(SymbolName) base_ ## SymbolName
#define TYPE_NAME(SymbolName) SymbolName ## _t

// must be compiled as C++ or else the macro below will fail to build:
// error: initializer element is not constant
#define INTERCEPT(ReturnType, SymbolName, ...) \
	typedef ReturnType (*TYPE_NAME(SymbolName))(__VA_ARGS__); \
	static void * const BASE_NAME(SymbolName) = dlsym(RTLD_NEXT, STR(SymbolName)); \
	ReturnType SymbolName(__VA_ARGS__)
#define BASE(SymbolName) ((TYPE_NAME(SymbolName))BASE_NAME(SymbolName))


extern "C" char * program_invocation_short_name; // provided by glibc


void steamwm_init(void) __attribute__((constructor));
void steamwm_init(void)
{
	// Only attach to steam!
	if (strcmp(program_invocation_short_name, "steam") != 0) {
		return;
	}

	// Prevent steamwm.so from being attached to processes started by steam
	const char *envname = "LD_PRELOAD";
	const char *oldenv = getenv(envname);

	if (oldenv) {
		char *env = strdup(oldenv);
		char *pos = strstr(env, STR(SONAME));
		if (pos) {
			size_t len1 = strlen(STR(SONAME));
			size_t len2 = strlen(pos + len1);
			memmove(pos, pos + len1, len2);
			*(pos + len2) = '\0';
			setenv(envname, env, 1);
		}
		free(env);
	}
}

static bool pid_set = false;
//static bool hostname_set = false;

INTERCEPT(int, XChangeProperty,
	Display *             dpy,
	Window                w,
	Atom                  property,
	Atom                  type,
	int                   format,
	int                   mode,
	const unsigned char * data,
	int                   n
)
{
	// set the process ID (_NET_WM_PID)
	if (!pid_set) {
		Atom pid_prop = XInternAtom(dpy, "_NET_WM_PID", False);
		pid_t pid = getpid();
		unsigned char *ptr = (unsigned char *)&pid;
		BASE(XChangeProperty)(dpy, w, pid_prop, XA_CARDINAL, 32, PropModeReplace, ptr, 1);
		pid_set = true;
	}

/*
	// set the hostname (WM_CLIENT_MACHINE)
	if (!hostname_set) {
		char  hostname[256];
		char *text_array[1];
		XTextProperty text_prop;

		gethostname(hostname, sizeof(hostname));
		hostname[sizeof(hostname) - 1] = '\0';
		text_array[0] = hostname;

		XStringListToTextProperty(text_array, 1, &text_prop);
		XSetWMClientMachine(dpy, w, &text_prop);
		XFree(text_prop.value);
		hostname_set = true;
	}
*/
	return BASE(XChangeProperty)(dpy, w, property, type, format, mode, data, n);
}

