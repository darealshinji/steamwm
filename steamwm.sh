#!/usr/bin/env bash
set -e

#// Various window management fixes for the Linux Steam client.
#//
#// You can set the following environment variables to 0 to disable individual features:
#//
#// STEAMWM_FORCE_BORDERS    Force borders on non-menu windows.
#//
#// STEAMWM_PREVENT_MOVE     Let the WM position non-menu/tooltip windows.
#//
#// STEAMWM_GROUP_WINDOWS    Group all steam windows.
#//                          This helps WMs with their focus stealing preventions,
#//                          and also prevents all Steam windows from being dimmed
#//                          (by KWin) if any Steam window has focus (is a KWin setting).
#//                          NOTE: Window is still dimmed when showing menus/tooltips :(
#//
#// STEAMWM_SET_WINDOW_TYPE  Tell the WM which Steam windows are dialogs.
#//                          This lets the window manager place them more intelligently.
#//                          For example, the WM might center dialogs.
#//                          NOTE: We simply treat every window with a title other than
#//                                "Steam" or "Friends" as a dialog window.
#//                                The startup window is also marked as a dialog.
#//
#// STEAMWM_MANAGE_ERRORS    Steam sets error dialogs as unmanaged windows - fix that.
#//
#//
#// Obsolete fixes (now disabled by default):
#//
#// STEAMWM_FIX_NET_WM_NAME  Set _NET_WM_NAME to the WM_NAME value to get better window
#//                          titles (and add " - Steam" suffix if needed).
#//                          Steam now doesn't set WM_ICON_NAME, _NET_WM_NAME or
#//                          _NET_WM_ICON_NAME anymore - while it would be better to set
#//                          them, their absence is unlikely to cause problems.
#//
#// STEAMWM_SET_FIXED_SIZE   Set fixed size hints for windows with a fixed layout.
#//
#//
#// Requires: g++ with support for x86 targets, Xlib + headers
#//
#//
#// Use:
#// $ chmod +x steamwm.cpp
#// and then
#//
#//
#// $ DEBUGGER="$(pwd)/steamwm.cpp" steam
#//
#// *or*
#//
#// $ ./steamwm.cpp steam                    // Prints ld.so errors on 64-bit systems
#//
#// *or*
#//
#// $ ./steamwm.cpp                          // Compile
#// $ LD_PRELOAD="$(pwd)/steamwm.so" steam   // Prints ld.so errors on 64-bit systems
#//
#//
#// DISCLAIMER: Use at your own risk! This is in no way endorsed by VALVE.
#//
#// This program is free software. It comes without any warranty, to
#// the extent permitted by applicable law. You can redistribute it
#// and/or modify it under the terms of the Do What The Fuck You Want
#// To Public License, Version 2, as published by Sam Hocevar. See
#// http://sam.zoy.org/wtfpl/COPYING for more details.
#//


[ -z $STEAMWM_FORCE_BORDERS   ] && export STEAMWM_FORCE_BORDERS=1
[ -z $STEAMWM_PREVENT_MOVE    ] && export STEAMWM_PREVENT_MOVE=1
[ -z $STEAMWM_FIX_NET_WM_NAME ] && export STEAMWM_FIX_NET_WM_NAME=0
[ -z $STEAMWM_GROUP_WINDOWS   ] && export STEAMWM_GROUP_WINDOWS=1
[ -z $STEAMWM_SET_WINDOW_TYPE ] && export STEAMWM_SET_WINDOW_TYPE=1
[ -z $STEAMWM_SET_FIXED_SIZE  ] && export STEAMWM_SET_FIXED_SIZE=0
[ -z $STEAMWM_MANAGE_ERRORS   ] && export STEAMWM_MANAGE_ERRORS=1


self="$(readlink -f "$(which "$0")")"
#name="$(basename "$self" .sh)"
name="steamwm"
out="$(dirname "$self")/$name"
soname="$name.so"
cpp="$name.cpp"


#// On amd64 platforms, compile a dummy 64-bit steamwm.so,
#// so that native 64-bit tools invoked by Steam and its
#// launch script won't spam (harmless) ld.so errors.
if [ -f '/lib64/ld-linux-x86-64.so.2' ] ; then
	dout="$out/64"
	mkdir -p "$dout"
	if ! [ -f "$dout/$soname" ] ; then
		echo -e "\n" | gcc -shared -fPIC -m64 -x c - -o "$dout/$soname" &> /dev/null
		strip "$dout/$soname" &> /dev/null
		#// ignore all errors - this may at worst cause warnings later
	fi
	export LD_LIBRARY_PATH="$dout:$LD_LIBRARY_PATH"
fi


#// Compile the LD_PRELOAD library
mkdir -p "$out"
if [ "$self" -nt "$out/$soname" ] ; then
	echo "Compiling $soname..."
	g++ -shared -fPIC -m32 -x c++ "$cpp" -o "$out/$soname" \
	    -lX11 -static-libgcc -static-libstdc++ \
	    -O3 -Wall -Wextra -DSONAME="$soname" \
		|| exit 1
fi


#// Run the executable
export LD_PRELOAD="$soname:$LD_PRELOAD"
export LD_LIBRARY_PATH="$out:$LD_LIBRARY_PATH"
#[ -z "$1" ] || exec "$@"
bash "$(dirname "$self")/run-steam.sh" $@

