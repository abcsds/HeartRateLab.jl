# JuliaCon 2026 Quarto reveal.js template

A Quarto reveal.js theme + reference deck matching the JuliaCon 2026 brand,
sharing its palette and typography with `docs/poster/juliacon2026_poster.tex`.

## Why this exists

JuliaCon has **no official slide-deck template** — checked `JuliaCon/presentations`
(an archive of old talks, no reusable theme) and the 2025/2026 website assets
(`github.com/JuliaCon/www.juliacon.org`, `franklin` branch). The only branded
talk-related asset is `_assets/2025/img/talks_template.svg`, a square **social-media
announcement card** ("Lightning Talk — Your name / Your title"), not a presentation
deck. This template fills that gap, built from the same brand extraction used for
the poster (indigo bubble background, Julia-logo accent colors, bold sans).

## Files

| File | What |
|------|------|
| `juliacon2026.scss` | The reveal.js theme — drop into any deck's `theme:` list |
| `juliacon2026-template.qmd` / `.html` | Reference deck: one slide per pattern |
| `img/logos-hrl.png` | The three institutional logos on a white pill (full-res source; see *Institutional logos*) |
| `img/logos-hrl-opt.png` | Palette-optimised copy that is base64-inlined into the theme |
| `img/MedUniGraz.svg` / `.png` | Med Uni Graz logo (from Wikimedia Commons `Med_Uni_Graz_Logo.svg`) |
| `img/qr-repo.png` | Transparent-background QR (generated via LaTeX `qrcode` + Ghostscript, same pipeline as the poster) |
| `img/juliacon-bubble-bg*.jpg` | Unused — leftover from an abandoned bead-texture experiment (safe to delete) |

## Background

The title / section-divider slides use a **violet linear gradient**
(`linear-gradient(160deg, #2b0836 0%, #1a0526 52%, #120118 100%)`), painted
edge-to-edge by reveal's native background layer (`data-background-gradient` via
`title-slide-attributes` and `{background-gradient="…"}` on the headings). The
palette is sampled from the official JuliaCon 2026 Mainz banner. (An earlier
attempt used a photographic bead texture extracted from the 2025 announcement-card
SVG — abandoned as too busy/off-brand for 2026; the leftover `juliacon-bubble-bg*.jpg`
are unused.)

## Institutional logos

The **title slide** carries the three HRL affiliation logos — **TU Graz · Med Uni
Graz · Universidad La Salle Bajío (Centro de Neurociencias)** — on a white pill so
they read on the dark violet. (Last year's ICCM/MathPsych deck had only the first
and third; Med Uni Graz is added here.) Logo-lockup guidelines applied: equal
height, consistent clear space, aspect preserved, full-colour on white.

- Combined bar: `img/logos-hrl.png` (built from `../../img/TU_Graz.png`,
  `img/MedUniGraz.png`, `../../img/Neurociencias_Color.png` — equal-height row on a
  rounded white pill). Rebuild with ImageMagick, then re-inline (below).
- The bar is **base64-inlined** into `juliacon2026.scss` as the background of
  `.reveal:has(section#title-slide.present)::after`. It's inlined because Quarto
  compiles the theme SCSS to a hashed CSS deep under `_files/`, where a relative
  `url()` would not resolve. To change the logos: rebuild `logos-hrl.png`, run
  `magick logos-hrl.png -resize 1300x PNG8:logos-hrl-opt.png`, then replace the
  `data:image/png;base64,…` string in the `::after` rule with
  `base64 -w0 img/logos-hrl-opt.png`.
- It is anchored to `.reveal` (the viewport container) via `:has()` so it sits at
  the slide bottom **independent of the title's height** and shows **only on the
  title slide**. A reduced-motion-safe fade-up (`@keyframes jc-logo-fade`, gated by
  `prefers-reduced-motion`) brings it in with the title.

Render the reference deck yourself: `quarto render juliacon2026-template.qmd`
(pure HTML/CSS — no Julia kernel needed, renders on any machine with Quarto).

## Using it in `HeartRateLab.qmd`

The existing talk (`docs/slides/HeartRateLab.qmd`) already targets
`format: revealjs` (plus `beamer`/`pdf`/`html`). To adopt the theme, change its
YAML `theme:` line:

```yaml
format:
  revealjs:
    theme: [default, ../juliacon2026-template/juliacon2026.scss]
    # keep the rest of the existing revealjs options (slideNumber, logo, chalkboard, …)
```

(Quarto merges multiple SCSS themes in `theme:` — `default` supplies the base
reveal.js framework variables, `juliacon2026.scss` overrides them.)

Then, slide by slide, pull in only the patterns you want:

- **Section dividers** — add
  `{.section-slide background-image="img/juliacon-bubble-bg-dim.jpg" background-size="cover" background-position="center"}`
  to any `#`/`##` heading for a full-bleed official-texture slide (the
  `background-image` on reveal's native layer is what makes it edge-to-edge — see
  *Full-bleed backgrounds* below). For the auto title slide, set the same image via
  `title-slide-attributes: {data-background-image: "img/…-dim.jpg", data-background-size: cover}`
  in the YAML, and `center: true` so divider/title text is vertically centred.
  (Adjust the image path to be relative to the deck you're merging into.)
- **Callouts** — no syntax change needed. `::: {.callout-note}` /
  `.callout-tip` / `.callout-important` / `.callout-caution` already render in
  brand colors (blue / green / red / gold).
- **Stat pills** — wrap a number in `[+2.64σ]{.jc-stat .jc-stat-elevated}` (or
  `-typical` / `-borderline`) to echo the poster's z-score coloring inline.
- **juliacon badge** — copy the `.juliacon-badge` HTML block from the template's
  closing slide for a title/closer wordmark (pure CSS dots, no image asset).
- **Down-slides (vertical stacks)** — a `#` heading is both a section divider
  **and the top of a vertical stack**: every `##` after it becomes a nested
  *down-slide* you reach with <kbd>↓</kbd>. This nesting is automatic in Quarto
  (no class needed). See the template's *Section dividers & down-slides* slide and
  its three children. Park optional / backup detail there. **You must set
  `navigation-mode: vertical`** in the YAML for the ↓/↑ keys to actually descend:
  Quarto's default is `navigation-mode: linear`, which flattens stacks into the
  horizontal flow so down-slides slide in from the **right** instead of down.
  (`vertical` maps to reveal's `navigationMode: 'default'` = real 2D navigation.)
- Two-column layouts, code blocks, tables, and blockquotes need **no changes** —
  they pick up the theme automatically.

### Full-bleed backgrounds — use reveal's native layer, not the `<section>`

Indigo slides (title + `.section-slide`) get their look from reveal's **native
background layer** via `data-background-image` (the official bead texture — see
*Background provenance*), set with `title-slide-attributes:` in the YAML (for the
auto title slide) and `{background-image="…"}` on the heading (for dividers). That
native layer covers the **whole viewport including reveal's 8% margin**, so there
is no white frame around the image. Do **not** paint the background on the `<section>`
itself and do **not** set `position`/`height` on it. Concretely, three overrides
that each caused a real bug and are now gone:

- `background` on the `<section>` → white margin frame ("purple framed in white").
- `height: 100%` → breaks reveal's vertical-stack math, down-slides go off-screen.
- `position: relative` → breaks reveal's vertical **centering** (reveal centers a
  slide by setting `top:` on the absolutely-positioned section; `relative` drops
  the content to the bottom, out of frame). The theme therefore adds **no**
  `position` — and consequently no `::before` bubble overlay (which needed it).
  Vertical centering is `center: true`; the closing slide adds `.jc-center` for
  horizontal centering too.

## Design notes

- **Font**: Fira Sans / Fira Mono, loaded from Google Fonts (`@import` in the
  SCSS) with a system-sans fallback stack — looks right whenever the viewing
  browser has internet (the normal case for a talk), degrades gracefully
  offline.
- **Indigo background**: a single reveal-native `linear-gradient` (see above); no
  raster asset, no `::before` overlay (an earlier bubble-texture overlay was
  dropped because it required `position: relative`, which broke centering). The
  selectors use a **descendant** combinator (`.reveal .slides section.section-slide`,
  not `> section`) because a `#` divider that heads a vertical stack is nested
  inside reveal's `.stack` wrapper and is not a direct child of `.slides`. Note
  Quarto's auto title slide is `#title-slide` with class `.quarto-title-block`
  (there is **no** `.title-slide` class on it), so the id selector is what
  matches. Vertical centering of dividers/title comes from `center: true`, not a
  flex/`height:100%` hack (which breaks vertical stacks — see above).
- Palette identical to the poster: `#38376C`/`#201C46` indigo,
  `#389826`/`#CB3C33`/`#9558B2`/`#4063D8` Julia-logo accents, `#F3E8F2` lavender.

## Verified

Rendered with local Quarto 1.8.27 and screenshotted with headless Chromium
(driven over the DevTools protocol so vertical slides navigate properly) —
title, section divider, two-column, callouts, stat pills, code blocks, the
closing QR slide, and the three down-slides all confirmed rendering correctly
full-bleed with no white frame. Screenshots live in `previews/`.
