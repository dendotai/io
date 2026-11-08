# One line per panel open in the panel log, for issue 25: hover enters, same-row exit-then-enter pairs, missed exits, fills cleared by the tick, rows grey at close, and BAD when the pairs are over half the enters.
# Usage: cat ~/Library/Logs/io/panel.1.log ~/Library/Logs/io/panel.log | awk -f scripts/panel-log/opens.awk
/ menu open #/ { open = 1; pid = $2; t = substr($1, 1, 23); enters = 0; pairs = 0; missed = 0; clears = 0; last = ""; delete grey }
open && / hover enter: / { enters++; split($0, h, "hover enter: "); split(h[2], nm, " frame="); if (nm[1] == last) pairs++; last = "" }
open && / hover exit: / { split($0, h, "hover exit: "); split(h[2], nm, " frame="); last = nm[1] }
open && / MISSED-EXIT / { missed++ }
open && / fill cleared by tick: / { clears++ }
open && / fill (hovered|highlighted): / { split($0, h, ": "); split(h[2], nm, " frame="); grey[nm[1]] = 1 }
open && / fill none: / { split($0, h, "fill none: "); split(h[2], nm, " frame="); delete grey[nm[1]] }
open && / BAD-OPEN / { marked = 1 }
/ menu close #/ { if (open) { c = 0; for (k in grey) c++; printf "%s %-6s open #%-3s enters=%-4d pairs=%-4d missed=%-2d clears=%-2d grey-at-close=%d %s%s\n", t, pid, substr($4, 2), enters, pairs, missed, clears, c, (enters >= 10 && pairs * 2 > enters) ? "BAD " : "", marked ? "BAD-OPEN" : "" } open = 0; marked = 0 }
