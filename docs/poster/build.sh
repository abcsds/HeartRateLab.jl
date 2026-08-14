#!/usr/bin/env bash
# Build the JuliaCon 2026 poster:
#   1. compile juliacon2026_poster.tex -> juliacon2026_poster.pdf
#   2. rasterise a flat preview        -> juliacon2026_poster_preview.png (ghostscript)
#
# ALWAYS runs pdflatex TWICE. The full-page background is a TikZ `remember
# picture, overlay`, which needs a second pass to learn the page geometry — a
# single pass renders it with no coordinates and the whole background comes out
# WHITE. (latexmk was skipping that second pass on incremental rebuilds, which is
# exactly how the background broke.) A flock guard serialises concurrent runs so
# the watcher and a manual build can't clobber each other's aux/ mid-compile.
#
# Intermediates go in ./aux/ (gitignored); only the PDF and preview PNG land next
# to the .tex. Figures are NOT regenerated here. Run ./watch.sh for build-on-save.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

TEX=juliacon2026_poster.tex
BASE=juliacon2026_poster
AUX=aux
PREVIEW_DPI=${PREVIEW_DPI:-150}
LOCK=".build.lock"   # stable path OUTSIDE aux/ so `rm -rf aux` can't drop the lock mid-race

PDFLATEX=$(command -v pdflatex || true)
[ -n "$PDFLATEX" ] || { echo "[poster] ERROR: pdflatex not found on PATH" >&2; exit 1; }

# Locate ghostscript (on NixOS `gs` is often only under /nix/store, and may be a
# shell alias in an interactive shell), so fall back to a store glob.
GS=$(command -v gs 2>/dev/null || true)
if [ -z "${GS}" ] || ! "${GS}" --version >/dev/null 2>&1; then
  GS=$(ls -1 /nix/store/*ghostscript*/bin/gs 2>/dev/null | head -1 || true)
fi

mkdir -p "${AUX}"

# Serialise: if another build (e.g. the watcher) holds the lock, wait for it.
exec 9>"${LOCK}"
flock 9

echo "[poster] compiling ${TEX} (pass 1/2) ..."
"${PDFLATEX}" -interaction=nonstopmode -halt-on-error -output-directory="${AUX}" "${TEX}" >/dev/null
echo "[poster] compiling ${TEX} (pass 2/2) ..."
"${PDFLATEX}" -interaction=nonstopmode -halt-on-error -output-directory="${AUX}" "${TEX}" >/dev/null

cp -f "${AUX}/${BASE}.pdf" "${BASE}.pdf"
echo "[poster] wrote ${BASE}.pdf ($(grep -oE '\([0-9]+ pages?' "${AUX}/${BASE}.log" | tail -1 | tr -d '('))"

if [ -n "${GS}" ]; then
  "${GS}" -q -dNOPAUSE -dBATCH -sDEVICE=png16m -r"${PREVIEW_DPI}" \
          -sOutputFile="${BASE}_preview.png" "${BASE}.pdf"
  echo "[poster] wrote ${BASE}_preview.png (${PREVIEW_DPI} dpi)"
else
  echo "[poster] WARNING: ghostscript not found — skipped preview PNG" >&2
fi
