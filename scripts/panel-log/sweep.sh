#!/bin/zsh
# Usage: swiftc -O scripts/panel-log/pointer.swift -o scripts/panel-log/pointer; scripts/panel-log/sweep.sh [cycles]. Moves the real pointer, so nobody uses the computer while it runs.
# Opens io's panel, sweeps the pointer down all rows in about half a second, moves out, closes, N times. Reads the item and the panel frame before each pointer step.
S=$(cd "$(dirname "$0")" && pwd)
N=${1:-40}
LOG=~/Library/Logs/io/panel.log
MAIN_H=1117
for i in $(seq 1 $N); do
  read -r ix iy iw ih <<< "$(osascript -e 'tell application "System Events" to get {position, size} of menu bar item 1 of menu bar 2 of process "io"' | tr -d ',')"
  [[ -z "$ih" || "$iw" == "0" ]] && { echo "cycle $i: status item not found"; exit 1; }
  cx=$(( ix + iw / 2 )); cy=$(( iy + ih / 2 ))
  before=$(wc -l < $LOG | tr -d " ")
  osascript -e 'tell application "System Events" to click menu bar item 1 of menu bar 2 of process "io"' >/dev/null 2>&1
  sleep 0.6
  read -r mw mh <<< "$(osascript -e 'tell application "System Events" to get size of menu 1 of menu bar item 1 of menu bar 2 of process "io"' 2>/dev/null | tr -d ',')"
  [[ -z "$mh" || "$mh" == "0" ]] && { echo "cycle $i: menu did not open (size $mw $mh)"; exit 1; }
  frame=$(tail -n +$before $LOG | grep -m1 ' panel window ' | sed -E 's/.*frame=\(([-0-9.]+), ([-0-9.]+), ([-0-9.]+), ([-0-9.]+)\).*/\1 \2 \3 \4/')
  [[ -z "$frame" ]] && { echo "cycle $i: no panel window line"; exit 1; }
  read -r fx fy fw fh <<< "$frame"
  top=$(printf '%.0f' $(( MAIN_H - fy - fh ))); bottom=$(printf '%.0f' $(( MAIN_H - fy ))); midx=$(printf '%.0f' $(( fx + fw / 2 )))
  steps=45
  for s in $(seq 0 $steps); do
    y=$(( top + 12 + (bottom - top - 24) * s / steps ))
    $S/pointer move $midx $y
    sleep 0.01
  done
  $S/pointer move $(( midx + fw )) $(( bottom - 40 ))
  sleep 0.3
  osascript -e 'tell application "System Events" to perform action "AXCancel" of menu 1 of menu bar item 1 of menu bar 2 of process "io"' >/dev/null 2>&1
  sleep 0.5
  read -r mw mh <<< "$(osascript -e 'tell application "System Events" to get size of menu 1 of menu bar item 1 of menu bar 2 of process "io"' 2>/dev/null | tr -d ',')"
  if [[ -n "$mh" && "$mh" != "0" ]]; then $S/pointer click $cx $cy; sleep 0.5; fi
  echo "cycle $i: item $cx,$cy panel top=$top bottom=$bottom x=$midx"
done
