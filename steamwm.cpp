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

	fprintf(stderr, "\n[steamwm] attached to steam\n");
}

static void name_changed(Display * dpy, Window w, const unsigned char * data, int n);

INTERCEPT(void, XSetWMName,
	Display *       dpy,
	Window          w,
	XTextProperty * prop
)
{
	if (prop->format == 8) {
		// The libX11 pulled in with STEAM_RUNTIME=1 has XSetWMName (or XSetTextProperty?)
		// liked/optimized to use internal functions and not the global XChangeProperty,
		// so our override below won't work -> also intercept XSetWMName().
		name_changed(dpy, w, prop->value, prop->nitems);
	}

	return BASE(XSetWMName)(dpy, w, prop);
}

static bool pid_set = false;
static bool hostname_set = false;
//static bool shutdown_sent = false;

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
	if (property == XA_WM_NAME && format == 8) {
		name_changed(dpy, w, data, n);
	}

	/* set the process ID (_NET_WM_PID) */
	if (!pid_set) {
		Atom pid_prop = XInternAtom(dpy, "_NET_WM_PID", False);
		pid_t pid = getpid();
		unsigned char *ptr = (unsigned char *)&pid;
		BASE(XChangeProperty)(dpy, w, pid_prop, XA_CARDINAL, 32, PropModeReplace, ptr, 1);
		pid_set = true;
	}

	/* set the hostname (WM_CLIENT_MACHINE) */
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

	return BASE(XChangeProperty)(dpy, w, property, type, format, mode, data, n);
}

static void name_changed(Display * dpy, Window w, const unsigned char * data, int n)
{
	// Use the XA_WM_NAME as both XA_WM_NAME and _NET_WM_NAME.
	// Steam sets _NET_WM_NAME to just "Steam" for all windows.
	const unsigned char * name = data;
	unsigned char * buffer = NULL;
	int nn = n;

	if (n > 0 && strstr((char *)data, "Steam") == 0) {
		// Make sure "Steam" is in all window titles.
		char suffix[] = " - Steam";
		nn = n + sizeof(suffix) - 1;
		name = buffer = (unsigned char *)malloc(nn + 1);
		memcpy(buffer, data, n);
		memcpy(buffer + n, suffix, sizeof(suffix));
	}

	Atom net_wm_name = XInternAtom(dpy, "_NET_WM_NAME", False);
	Atom utf8_string = XInternAtom(dpy, "UTF8_STRING", False);
	BASE(XChangeProperty)(dpy, w, net_wm_name, utf8_string, 8, PropModeReplace, name, nn);

	if (buffer) {
		free(buffer);
	}
}
