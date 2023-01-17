Launch Steam without tray icon and force the client to shut down after clicking on the "close window" symbol.
Still very experimental.

Forked from https://github.com/dscharrer/steamwm

`steamwm.cpp:` will be compiled in a library that will be preloaded and sets the _NET_WM_PID value for the Steam window

`wmctrl.c:` modified version of wmctrl that checks if a given PID is among the open windows

`hacks/libappindicator.so.1:` modified appindicator library to force the creation of a Steam tray icon to fail

`run-steam.sh:` starts Steam and sends the "shutdown" command to it when the window disappeared
