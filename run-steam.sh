#!/usr/bin/env bash
set -e

SCRIPTDIR="$(cd "$(dirname "$0")" && echo $PWD)"
STEAMCONFIG="${HOME%/}/.steam"
STEAMROOT="$STEAMCONFIG/root"
PLATFORM="ubuntu12_32"
PIDFILE="$STEAMCONFIG/steam.pid"
LOGFILE="$SCRIPTDIR/steam.log"
HACKS="$SCRIPTDIR/hacks" # put the modified libappindicator library in here

# cd into directory where the "steam" binary is
cd "$STEAMROOT/$PLATFORM"

# set LD_LIBRARY_PATH
STEAM_RUNTIME_LIBRARY_PATH="$(./steam-runtime/run.sh --print-steam-runtime-library-paths)"
export LD_LIBRARY_PATH="$HACKS:$STEAMROOT/$PLATFORM:$STEAMROOT/$PLATFORM/panorama:$STEAM_RUNTIME_LIBRARY_PATH:${LD_LIBRARY_PATH-}"

# this is where the main window XID will be saved
export STEAM_XIDFILE="$SCRIPTDIR/steam.xid"

# normal Steam window behavior
export STEAMWM_FORCE_BORDERS=0
export STEAMWM_PREVENT_MOVE=0

# delete this first
rm -f "$STEAM_XIDFILE"

# launch Steam
./steam $* 2>&1 | tee "$LOGFILE" &

# wait until the "System startup time" message appeared in the log
n=0
while [ "x$(grep '^System startup time:.*' "$LOGFILE")" = "x" ]; do
  sleep 1
  n=$((n+1))
done
if [ $n -ge 60 ]; then
  echo "Timout"
  exit 1
fi

# wait until the steam.xid file was created
n=0
while [ ! -e "$STEAM_XIDFILE" ]; do
  sleep 1
  n=$((n+1))
done
if [ $n -ge 60 ]; then
  echo "Timout"
  exit 1
fi

WMCTRL="$SCRIPTDIR/wmctrl-mini"
if [ ! -x "$WMCTRL" ]; then
  gcc -Wall -O3 "$WMCTRL.c" -o "$WMCTRL" -lX11 -s
fi

XID=$(cat "$STEAM_XIDFILE")
PID=$(cat "$PIDFILE")

# stay in this loop until until the main windows are minimized into the tray
while [ "$("$WMCTRL" | grep $XID)" = "$XID" ]; do
  sleep 3
done

if [ -e "/proc/$PID/exe" ] && [ "x$(basename "$(readlink /proc/$PID/exe)")" = "xsteam" ]; then
  # send shutdown command to Steam
  echo '-shutdown' > "$STEAMCONFIG/steam.pipe"
fi

# wait until Steam was shutdown
wait $PID
STATUS=$?

zenity --info --text="Steam was shut down."

exit $STATUS

