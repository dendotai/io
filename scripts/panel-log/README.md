# Panel log readers

Tools for the rows-stay-grey diagnosis (issue 25). io writes `~/Library/Logs/io/panel.log` (rotated at 20 MB to `panel.1.log`) and copies every bad open, with a state dump and a system log slice, to `cases.log`, which never rotates.

- `opens.awk`: one line per panel open with its hover counts; a `BAD` or `BAD-OPEN` mark names an open in the bad state. `cat ~/Library/Logs/io/panel.1.log ~/Library/Logs/io/panel.log | awk -f scripts/panel-log/opens.awk`.
- `sweep.sh`: opens the panel through Accessibility, sweeps the real pointer down every row in about half a second, closes, and repeats; the posted events never showed the bad state in 40 cycles, so it checks that every log field prints, not that the state appears. Build `pointer.swift` first: `swiftc -O scripts/panel-log/pointer.swift -o scripts/panel-log/pointer`.
- `defaults write ai.den.io forceBadOpen -bool true` makes a Debug build mark its next open bad, to prove the dump path writes; `defaults delete ai.den.io forceBadOpen` ends it.
