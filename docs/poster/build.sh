#!/usr/bin/env bash
# Build the JuliaCon 2026 poster:
#   1. compile juliacon2026_poster.tex -> juliacon2026_poster.pdf  (via latexmk, 2+ passes for QR/refs)
#   2. rasterise a flat preview        -> juliacon2026_poster_preview.png  (via ghostscript)
#
# All LaTeX intermediates land in ./aux/ (gitignored); only the PDF and the
# preview PNG are written next to the .tex. Figures are NOT regenerated here —
# this only rebuilds the document from the .tex. Run ./watch.sh for build-on-save.
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")"

TEX=juliacon2026_poster.tex
BASE=juliacon2026_poster
AUX=aux
PREVIEW_DPI=${PREVIEW_DPI:-150}

# Locate ghostscript. On NixOS `gs` is often only under /nix/store (and may be a
# shell alias in an interactive shell), so fall back to a store glob.
GS=$(command -v gs 2>/dev/null || true)
if [ -z "${GS}" ] || ! "${GS}" --version >/dev/null 2>&1; then
  GS=$(ls -1 /nix/store/*ghostscript*/bin/gs 2>/dev/null | head -1 || true)
fi

mkdir -p "${AUX}"

echo "[poster] compiling ${TEX} ..."
latexmk -pdf -interaction=nonstopmode -halt-on-error -outdir="${AUX}" "${TEX}" >/dev/null

cp -f "${AUX}/${BASE}.pdf" "${BASE}.pdf"
echo "[poster] wrote ${BASE}.pdf"

if [ -n "${GS}" ]; then
  "${GS}" -q -dNOPAUSE -dBATCH -sDEVICE=png16m -r"${PREVIEW_DPI}" \
          -sOutputFile="${BASE}_preview.png" "${BASE}.pdf"
  echo "[poster] wrote ${BASE}_preview.png (${PREVIEW_DPI} dpi)"
else
  echo "[poster] WARNING: ghostscript not found — skipped preview PNG" >&2
fi
