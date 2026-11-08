#!/bin/zsh
# twelveclicks.sh [cycles]: the 13:06 case by script. Opens io's panel, slides the real pointer onto the AirPods row's ⌄, clicks it 12 times about 0.6 s apart, sweeps the pointer down the rows, moves out, closes, and prints one summary line per cycle from the panel log. Moves the real pointer, so nobody uses the computer while it runs.
S=$(cd "$(dirname "$0")" && pwd) # holds the built pointer and axpos tools
N=${1:-3}
LOG=~/Library/Logs/io/panel.log
AWK=$S/opens.awk
for i in $(seq 1 $N); do
  before=$(wc -l < $LOG | tr -d " ")
  osascript -e 'tell application "System Events" to click menu bar item 1 of menu bar 2 of process "io"' >/dev/null 2>&1
  for try in 1 2 3 4 5 6; do sleep 0.5; open_line=$(tail -n +$before $LOG | grep -m1 ' menu open #'); [[ -n "$open_line" ]] && break; done
  [[ -z "$open_line" ]] && { echo "cycle $i: no menu open line"; exit 1; }
  mainh=$(echo "$open_line" | sed -E 's/.*screens=(0,0 )?[0-9]+x([0-9]+)@.*/\2/')
  for try in 1 2 3 4; do pos=$($S/axpos $(pgrep -x io | head -1)); [[ "$pos" == *found* ]] && sleep 0.5 || break; done
  [[ "$pos" == *found* || -z "$pos" ]] && { echo "cycle $i: no Listening Mode button: $pos"; exit 1; }
  read -r bx by bw bh <<< "$pos"
  for try in 1 2 3 4; do panel=$(tail -n +$before $LOG | grep -m1 ' panel window ' | sed -E 's/.*frame=\(([-0-9.]+), ([-0-9.]+), ([-0-9.]+), ([-0-9.]+)\).*/\1 \2 \3 \4/'); [[ -n "$panel" ]] && break; sleep 0.5; done
  [[ -z "$panel" ]] && { echo "cycle $i: no panel window line"; exit 1; }
  read -r fx fy fw fh <<< "$panel"
  cx=$(( bx + bw / 2 )); cy=$(( by + bh / 2 )); rx=$(printf '%.0f' $fx); rw=$(printf '%.0f' $fw)
  for s in $(seq 0 10); do $S/pointer move $(( rx + rw + 40 - (rx + rw + 40 - cx) * s / 10 )) $cy; sleep 0.02; done
  sleep 0.4
  for c in $(seq 1 12); do $S/pointer click $cx $cy; sleep 0.35; done
  sleep 0.5
  bottom=$(printf '%.0f' $(( mainh - fy - 12 )))
  steps=60
  for s in $(seq 0 $steps); do $S/pointer move $(( cx - 10 )) $(( cy + (bottom - cy) * s / steps )); sleep 0.025; done
  $S/pointer move $(( rx + rw + 60 )) $bottom
  sleep 0.6
  osascript -e 'tell application "System Events" to perform action "AXCancel" of menu 1 of menu bar item 1 of menu bar 2 of process "io"' >/dev/null 2>&1
  sleep 0.6
  read -r mw mh <<< "$(osascript -e 'tell application "System Events" to get size of menu 1 of menu bar item 1 of menu bar 2 of process "io"' 2>/dev/null | tr -d ',')"
  if [[ -n "$mh" && "$mh" != "0" ]]; then
    read -r ix iy iw ih <<< "$(osascript -e 'tell application "System Events" to get {position, size} of menu bar item 1 of menu bar 2 of process "io"' | tr -d ',')"
    $S/pointer click $(( ix + iw / 2 )) $(( iy + ih / 2 )); sleep 0.5
  fi
  lines=$(tail -n +$before $LOG)
  echo "cycle $i: ⌄ at $cx,$cy foldstarts=$(echo "$lines" | grep -c 'removed from the end: 1[0-9]') clears=$(echo "$lines" | grep -c 'fill cleared by tick') missed=$(echo "$lines" | grep -c 'MISSED-EXIT') bad=$(echo "$lines" | grep -c 'BAD-OPEN') $(echo "$lines" | grep ' menu close #' | sed -E 's/.*(pairs=.*)/\1/' | cut -c1-80)"
  echo "$lines" | awk -f $AWK
done
