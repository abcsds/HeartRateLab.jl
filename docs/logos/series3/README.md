# Series 3 — typography-driven logos

Open **`../../series3.html`** for the showcase (18 designs + my top 3).

Built on the typography study in `../typography/` (JuliaMono Bold, measured glyph
metrics). The wordmark is **HeartRateLab** with **H·R·L** tinted purple/red/green
— the three syllable onsets = three beats. The core idea:

> The 12 monospace letters are **12 equal time-ticks**; the three beats land on
> cells **0·5·9** (H·R·L) — a real **5:4** inter-beat interval. The name itself
> is an HRV trace.

Bar/tachogram motifs from series 2 were **dropped** per feedback (we don't use
ECG or bar charts).

## Files
- `gen_series3.py` — parametric generator (all coords in em-units from
  `full_metrics.json`); edit here to add/adjust designs.
- `build_series3.py` — renders `../../series3.html` from `manifest3.json`.
- `svg/*.svg` — the 18 marks. **Text is live `<text font-family="JuliaMono">`,
  not outlined**, so letter fills stay animatable (needs JuliaMono installed, or
  swap in an outlined copy for full portability).
- `manifest3.json` — per-design docs incl. `anim` / `prints` / `color` notes.

Rebuild: `python3 gen_series3.py && python3 build_series3.py`

## My top 3
1. **`word-comb-underline`** — the wordmark riding its own inter-beat comb (grey
   ticks = time axis, three colour caps = beats). Best primary logo; most
   animation-ready.
2. **`word-comb-below`** — the comb-at-bottom hero: 12 equal ticks, three beats
   at the true 5:4.
3. **`hrl-comb-below`** — the compact monogram; the cleanest home for the bounce
   loop, crops to a favicon.

Round companion for the intro animation: **`hrl-ring`** / **`hrl-ring-dots`**.

## Animation roadmap (documented for later; see also GUIDELINES §7)
Two moves are baked into the geometry:

1. **Linear bounce → wordmark.** One ball bounces H→R→L along the comb, stamping
   a Julia dot on each capital, then wraps. Time-of-flight ∝ distance (constant
   horizontal speed), apex ∝ distance² → the long H→R hop hangs 1.56× higher than
   R→L. Ball colour = the colour it is about to stamp. The 12 grey ticks stay
   static as the metronome; only the three caps light up. Designs that support
   it directly: `word-comb-below`, `word-comb-underline`, `combo-ticks-rising`,
   `hrl-comb-below`.
2. **Round → line ("unroll").** The ticked ring (`hrl-ring`) opens at the top and
   unrolls into the straight comb while the three beats slide to H·R·L and the
   wordmark fades in — a circular intro that resolves into the logo.
   Storyboard frame: `hrl-unroll-still`.

### Per-use advantages (summary)
- **Animation:** `word-comb-underline`, `word-comb-below`, `hrl-comb-below`,
  `combo-ticks-rising`, `word-bounce-still` (key-frame), `hrl-unroll-still`.
- **Print / 1-colour:** `word-mono` (outline-ring beats, no colour needed);
  `combo-min-underline` (three short strokes); any comb mark drops to ink cleanly.
- **Colour question:** `word-orange` shows the middle beat in literal orange
  (#E8802B) vs Julia red — change in one place (`ORG`/`RD`) if adopted.
- **Favicon / tiny:** `hrl-favicon`, `hrl-ring-dots`.

Palette: purple `#9558B2` · red `#CB3C33` · green `#389826` · blue `#4063D8`
(reserved) · ink `#1b1b1f`.
