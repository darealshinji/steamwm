#!/usr/bin/env bash
set -e

SCRIPTDIR="$(cd "$(dirname "$0")" && echo $PWD)"
STEAMCONFIG="${HOME%/}/.steam"
STEAMROOT="$STEAMCONFIG/root"
PLATFORM="ubuntu12_32"
PIDFILE="$STEAMCONFIG/steam.pid"
LOGFILE="$SCRIPTDIR/steam.log"

# cd into directory where the "steam" binary is
cd "$STEAMROOT/$PLATFORM"

# check if Steam is already running
PID=$(cat "$PIDFILE")
if [ -e "/proc/$PID/exe" ] && [ "x$(basename "$(readlink /proc/$PID/exe)")" = "xsteam" ]; then
  echo "warning: Steam is already running"
  ./steam -foreground
  exit 1
fi

# set LD_LIBRARY_PATH
STEAM_RUNTIME_LIBRARY_PATH="$(./steam-runtime/run.sh --print-steam-runtime-library-paths)"
export LD_LIBRARY_PATH="$SCRIPTDIR/hacks:$STEAMROOT/$PLATFORM:$STEAMROOT/$PLATFORM/panorama:$STEAM_RUNTIME_LIBRARY_PATH:${LD_LIBRARY_PATH-}"
export LD_PRELOAD="$SCRIPTDIR/steamwm.so:${LD_PRELOAD-}"

# launch Steam
./steam $* 2>&1 | tee "$LOGFILE" &
export LD_PRELOAD=""

# wait until the "System startup time" message appeared in the log
n=0
while [ "x$(grep '^System startup time:.*' "$LOGFILE")" = "x" ]; do
  sleep 1
  n=$((n+1))
  if [ $n -gt 60 ]; then
    echo "Timout"
    exit 1
  fi
done

WMCTRL="$SCRIPTDIR/wmctrl"
PID=$(cat "$PIDFILE")

# stay in this loop until until the main windows are minimized into the tray
while [ "x$($WMCTRL $PID)" = "xfound" ]; do
  sleep 3
done

if [ -e "/proc/$PID/exe" ] && [ "x$(basename "$(readlink /proc/$PID/exe)")" = "xsteam" ]; then
  # send shutdown command to Steam
  echo '-shutdown' > "$STEAMCONFIG/steam.pipe"
fi

# wait until Steam was shutdown
wait $PID
STATUS=$?

#zenity --info --text="Steam was shut down."

exit $STATUS

