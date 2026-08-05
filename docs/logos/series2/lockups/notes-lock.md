# HeartRateLab.jl — Logo Lockups (Series 2)

10 "icon + wordmark" lockups, all built on Base B (Triad + name Lockup) but with
the ECG baseline replaced by honest IBI vocabulary per BRIEF2's hard rule.
Colors: purple `#9558B2`, red `#CB3C33`, green `#389826` (Julia dots), ink
`#1A1A1A`, muted grey `#8A8F98`. All wordmarks use
`font-family="Arial, Helvetica, sans-serif" font-weight="700"` with
`textLength` + `lengthAdjust="spacingAndGlyphs"` for stable fit; verified by
rendering every file to PNG and inspecting a contact sheet (no tofu/clipping,
text spells "HeartRateLab" correctly throughout).

---

### lock-01
- **title:** Triad on the Timeline
- **concept:** The three Julia dots sit directly on a plain horizontal baseline with visibly unequal gaps (60 / 76) — the gaps *are* the inter-beat intervals, no waveform involved.
- **motif:** beat-event dots on a timeline
- **register:** clean, confident, closest sibling to Base B but ECG-free
- **wordmark:** includes text ("HeartRateLab")
- **viewBox:** 640×220 (horizontal)
- **why_it_works:** most legible/neutral option; reads instantly as "events on a line," safe default lockup
- **risk:** low; could be seen as generic if not paired with the tick-comb variants elsewhere in the set

### lock-02
- **title:** Tick-Comb Mini
- **concept:** Three colored ticks (unequal spacing and unequal heights = unequal IBI durations), each capped with a small dot echoing the Julia mark — a compact, icon-first version of Base A's comb.
- **motif:** IBI tick-comb (event raster), dot-capped
- **register:** technical, precise, "data instrument" feel
- **wordmark:** includes text ("HeartRateLab")
- **viewBox:** 640×220 (horizontal)
- **why_it_works:** ties directly to Base A's hero idea while staying lockup-sized; ticks read as a tiny waveform-free ECG substitute
- **risk:** at very small sizes the dot caps could fuse visually with the ticks — keep dot radius ≥ stroke width

### lock-03
- **title:** Measured Gap
- **concept:** Three dot-beats on a timeline, plus a small caliper/bracket explicitly measuring the interval between the last two beats — makes the "we measure intervals" story literal.
- **motif:** beat-event dots + interval bracket (caliper)
- **register:** analytical, instrumentation-flavored
- **wordmark:** includes text ("HeartRateLab")
- **viewBox:** 640×220 (horizontal)
- **why_it_works:** the caliper is unambiguous — nobody could mistake this for a heartbeat monitor
- **risk:** caliper is small at 32px icon scale; may need thicker strokes if used stand-alone below ~64px

### lock-04
- **title:** Underlined by the Comb
- **concept:** No separate icon block — the entire "HeartRateLab" wordmark is underlined by an irregular IBI tick comb; three of the ticks (in the wordmark's colors) are dot-capped, echoing the Julia identity inline with the type.
- **motif:** IBI tick-comb as underline / integrated type treatment
- **register:** editorial, modern wordmark-led
- **wordmark:** includes text ("HeartRateLab"), text is the hero element
- **viewBox:** 640×220 (horizontal)
- **why_it_works:** strongest "type-only" option in the set; comb underline scans as a data-signature rather than decoration
- **risk:** at small sizes the underline ticks can visually merge into a solid rule — keep for medium+ sizes (favicon should fall back to icon-only marks)

### lock-05
- **title:** Comb Stack
- **concept:** Stacked lockup — Base A's full tick-comb icon (grey ticks + 3 dot-capped colored ticks on a baseline) centered above the wordmark.
- **motif:** IBI tick-comb (event raster)
- **register:** technical, balanced, app-icon-adjacent
- **wordmark:** includes text ("HeartRateLab")
- **viewBox:** 360×300 (stacked)
- **why_it_works:** direct, undiluted port of the Base A hero icon into a stacked lockup — best pick if the brand wants one lockup that matches the standalone icon exactly
- **risk:** none major; verify icon/word vertical rhythm at target render sizes

### lock-06
- **title:** Triad Stack (Tight)
- **concept:** Stacked lockup — triad on a plain timeline (larger dots, unequal gaps) above a tightly tracked wordmark.
- **motif:** beat-event dots on a timeline
- **register:** bold, poster-like, condensed
- **wordmark:** includes text ("HeartRateLab")
- **viewBox:** 360×300 (stacked)
- **why_it_works:** big dots read well even at small stacked-icon sizes (e.g. app icon crops); tight tracking below gives a modern condensed feel
- **risk:** tight tracking pushes legibility slightly — keep textLength no smaller than used here

### lock-07
- **title:** Accented Heart
- **concept:** A small triad of dots sits as a decorative accent mark above the "a" in "Heart," standing in for a tittle/diaeresis — the three Julia dots become a type-level detail rather than a separate icon.
- **motif:** three dots as a type accent/tittle
- **register:** playful, wordmark-only, subtle
- **wordmark:** includes text ("HeartRateLab")
- **viewBox:** 640×220 (horizontal)
- **why_it_works:** most minimal/sophisticated option — no icon "box" at all, just a knowing detail for people who look twice
- **risk:** the accent is subtle by design; at very small sizes it may read as noise/dirt on the glyph — best for medium-to-large lockup use, not favicon

### lock-08
- **title:** Heart **Rate** Lab
- **concept:** "Rate" is set larger and in the red Julia color for emphasis (the product's core subject — heart RATE), paired with a tiny 3-tick dot-capped comb icon at left.
- **motif:** IBI tick-comb (mini) + weighted wordmark treatment
- **register:** confident, marketing-forward
- **wordmark:** includes text ("HeartRateLab", split into three same-baseline runs: "Heart" / "Rate" / "Lab")
- **viewBox:** 640×220 (horizontal)
- **why_it_works:** the weighted "Rate" is an easy, memorable reading aid and ties the accent color directly to the product's central concept
- **risk:** three separate `<text>` runs must stay perfectly baseline-aligned if the wordmark is ever re-flowed/localized; keep as one composed unit

### lock-09
- **title:** Big Icon, Wide Track
- **concept:** A larger triad-on-timeline icon (bigger dots, unequal gaps) with an interval caliper under the last gap, paired with a wordmark set at looser tracking and a slightly raised baseline relative to the icon — explores scale and alignment variation.
- **motif:** beat-event dots + interval caliper
- **register:** spacious, editorial, higher icon-to-word size ratio than lock-01/03
- **wordmark:** includes text ("HeartRateLab")
- **viewBox:** 640×220 (horizontal)
- **why_it_works:** demonstrates the lockup scales gracefully with a dominant icon, useful for hero/splash placements
- **risk:** the raised text baseline vs. icon center is a subtle asymmetry — intentional here, but shouldn't be mixed with lock-01/03's centered alignment in the same UI

### lock-10
- **title:** Compact Fused Mark
- **concept:** Three small unequal-spaced beat-dots tucked under-left on a short baseline, sitting close to and almost fusing with the wordmark for the tightest, most compact lockup in the set.
- **motif:** beat-event dots on a (short) timeline
- **register:** minimal, app-icon/nav-bar friendly
- **wordmark:** includes text ("HeartRateLab")
- **viewBox:** 640×220 (horizontal)
- **why_it_works:** smallest footprint of the horizontal set — best candidate for tight UI chrome (navbars, favicons-with-text, README badges)
- **risk:** the dots are small (r=15-17); keep a minimum render width (~200px) to preserve the Julia-dot identity

---

## Strongest picks
1. **lock-05** (Comb Stack) — most faithful, on-brand port of the Base A hero icon into a lockup; best "one true stacked lockup."
2. **lock-04** (Underlined by the Comb) — most distinctive type-led treatment; reads as a data signature, not decoration.
3. **lock-01** (Triad on the Timeline) — safest, most legible default horizontal lockup; good baseline for all other UI contexts.
