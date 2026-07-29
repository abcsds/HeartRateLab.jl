#!/usr/bin/env bash
# Vendor the JuliaMono weights used by the wordmark study into this folder.
# The report also falls back to a system-installed JuliaMono via @font-face local(),
# so this is only needed for a fully self-contained/offline copy or to re-measure.
set -euo pipefail
cd "$(dirname "$0")"

# 1) Prefer a system-installed JuliaMono (fontconfig)
if command -v fc-list >/dev/null 2>&1; then
  store="$(dirname "$(fc-list | grep -i 'JuliaMono-Bold.ttf' | head -1 | cut -d: -f1)")"
  if [ -n "${store:-}" ] && [ -d "$store" ]; then
    for w in Light Regular Medium SemiBold Bold ExtraBold; do
      [ -f "$store/JuliaMono-$w.ttf" ] && cp -f "$store/JuliaMono-$w.ttf" "./JuliaMono-$w.ttf" && echo "copied $w"
    done
    echo "done (from system: $store)"; exit 0
  fi
fi

# 2) Fallback: download from the JuliaMono release (OFL-licensed, redistributable)
base="https://github.com/cormullion/juliamono/raw/master"
for w in Light Regular Medium SemiBold Bold ExtraBold; do
  curl -sSL -o "JuliaMono-$w.ttf" "$base/JuliaMono-$w.ttf" && echo "downloaded $w"
done
echo "done (downloaded)"
