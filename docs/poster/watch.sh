#!/usr/bin/env bash
# Watch the poster's LaTeX and rebuild PDF + preview PNG on every save.
#
#   ./watch.sh          # runs until you press Ctrl-C
#
# Open juliacon2026_poster.pdf (or juliacon2026_poster_preview.png) in a viewer
# that reloads on change (evince, zathura, most image viewers) and just save the
# .tex — the outputs refresh within ~1s. No inotify required (plain mtime poll).
set -uo pipefail
cd "$(dirname "$(readlink -f "$0")")"
HERE="$(pwd)"

# Files that should trigger a rebuild.
WATCH=(juliacon2026_poster.tex)
[ -f ../references.bib ] && WATCH+=(../references.bib)

stamp() { stat -c %Y "${WATCH[@]}" 2>/dev/null | tr '\n' ' '; }

echo "[poster] watching: ${WATCH[*]}"
echo "[poster] save the .tex to rebuild — Ctrl-C to stop."
"${HERE}/build.sh" || echo "[poster] initial build FAILED — see aux/juliacon2026_poster.log"
last=$(stamp)

while true; do
  sleep 1
  cur=$(stamp)
  if [ "${cur}" != "${last}" ]; then
    last="${cur}"
    echo "[poster] $(date +%H:%M:%S) change detected — rebuilding ..."
    "${HERE}/build.sh" || echo "[poster] build FAILED — see aux/juliacon2026_poster.log"
  fi
done
