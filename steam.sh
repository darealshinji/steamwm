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
while [ "x$(grep '^System startup time:.*' "$LOGFILE")" = "x" ]; do
  sleep 1
done

# wait until the steam.xid file was created
while ! [ -e "$STEAM_XIDFILE" ]; do
  sleep 1
done

XID=$(cat "$STEAM_XIDFILE")

# stay in this loop until until the main windows are minimized into the tray
while [ "$(wmctrl -l | cut -d ' ' -f1 | grep $XID)" = "$XID" ]; do
  sleep 4
done

# send shutdown command to Steam
echo '-shutdown' > "$STEAMCONFIG/steam.pipe"

# wait until Steam was shutdown
PID=$(cat "$PIDFILE")
wait $PID
STATUS=$?

echo "Steam has finished with exit status $STATUS"
exit $STATUS

