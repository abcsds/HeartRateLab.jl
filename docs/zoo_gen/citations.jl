# ─────────────────────────────────────────────────────────────────────────────
# citations.jl — feature → seminal-reference map + light per-feature use-cases.
#
# Consumed by make_entry.jl to fill the `## Citation` and `## Use cases` sections
# of every dex entry. The feature→key mapping mirrors docs/src/zoo/_citations.md;
# keys resolve against docs/references.bib. `blurb` is a short who/what/year note
# rendered next to the citation link(s).
#
# CITATION_KEYS[name]  => Vector{String}  (seminal BibTeX keys, first = primary)
# CITATION_BLURB[name] => String          (human who/what/year prose)
# USE_CASES[name]      => String          (curated markdown bullets; optional —
#                                          falls back to the domain template)
#
# NB: this file covers the "## Citation" section (who *introduced* the
# measure). The "## Applications by area" section (real-world clinical /
# sports / meditation applications literature) is a SEPARATE map in
# `docs/zoo_gen/applications.jl` (`FAMILY_APPLICATIONS` / `VARIABLE_FAMILY` /
# `VARIABLE_NOTES`), with its own reference keys in `docs/references.bib`
# (zhang2016, bellenger2016, pascoe2017, ciccone2017, billman2013, etc.).
# `make_entry.jl` includes both files and cites both via DocumenterCitations
# `[key](@cite)`, so every application reference used there is automatically
# picked up by the `@bibliography` block on `docs/src/zoo/references.md` —
# nothing here needs to change for those refs to appear on regeneration.
# ─────────────────────────────────────────────────────────────────────────────

# ── Feature → seminal BibTeX key(s) ──────────────────────────────────────────
const CITATION_KEYS = Dict{String,Vector{String}}(
    # time domain
    "mean"      => ["taskforce1996"],
    "median"    => ["taskforce1996"],
    "max"       => ["taskforce1996"],
    "min"       => ["taskforce1996"],
    "range"     => ["taskforce1996"],
    "sdnn"      => ["kleiger1987", "wolf1978", "taskforce1996"],
    "sdann"     => ["kleiger1987", "wolf1978", "taskforce1996"],
    "sdsd"      => ["taskforce1996", "ewing1984"],
    "rmssd"     => ["taskforce1996", "ewing1984"],
    "pnn50"     => ["ewing1984", "taskforce1996"],
    "pnn20"     => ["mietus2002"],
    "cvnni"     => ["taskforce1996"],
    "cvsd"      => ["taskforce1996"],
    "rRR"       => ["vollmer2015"],
    "mean_hr"   => ["taskforce1996"],
    "std_hr"    => ["taskforce1996"],
    "max_hr"    => ["taskforce1996"],
    "min_hr"    => ["taskforce1996"],
    "median_hr" => ["taskforce1996"],
    "range_hr"  => ["taskforce1996"],
    # frequency domain (band powers additionally credit the Lomb–Scargle estimator)
    "ulf"           => ["bigger1996", "taskforce1996", "lomb1976"],
    "vlf"           => ["akselrod1981", "taskforce1996", "scargle1982"],
    "lf"            => ["akselrod1981", "taskforce1996", "moody1993"],
    "hf"            => ["akselrod1981", "taskforce1996"],
    "tp"            => ["akselrod1981", "taskforce1996", "welch1967"],
    "lf_peak"       => ["taskforce1996"],
    "hf_peak"       => ["taskforce1996"],
    "lf_hf_ratio"   => ["pagani1986", "taskforce1996"],
    "lf_relative"   => ["taskforce1996"],
    "hf_relative"   => ["taskforce1996"],
    "lf_percentage" => ["taskforce1996"],
    "hf_percentage" => ["taskforce1996"],
    # geometric (Poincaré / Lorenz plot)
    "sd1"              => ["tulppo1996", "brennan2001"],
    "sd2"              => ["tulppo1996", "brennan2001"],
    "sd2_sd1"          => ["tulppo1996", "toichi1997"],
    "sd1_sd2_area"     => ["brennan2001", "taskforce1996"],
    "cvi"              => ["toichi1997"],
    "ccsi"             => ["jeppesen2014"],
    "triangular_index" => ["malik1989", "taskforce1996"],
    "tinn"             => ["malik1989", "taskforce1996"],
    # nonlinear / entropy / fractal
    "apen"    => ["pincus1991"],
    "sampen"  => ["richman2000"],
    "fuzzyen" => ["chen2007"],
    "shan_en" => ["shannon1948"],
    "svd_en"  => ["roberts1999"],
    "spec_en" => ["inouye1991"],
    "perm_en" => ["bandt2002"],
    "mse"     => ["costa2002"],
    "renyi0"  => ["renyi1961"],
    "renyi1"  => ["renyi1961"],
    "renyi2"  => ["renyi1961"],
    "dfa2"    => ["peng1995", "peng1994", "francis2002", "iyengar1996"],
    "hurst"   => ["hurst1951"],
)

# ── Human who/what/year prose (rendered beside the citation link) ────────────
const CITATION_BLURB = Dict{String,String}(
    "mean"      => "Basic descriptive statistic of the Task Force (1996) time-domain panel; no earlier single origin.",
    "median"    => "Descriptive primitive standardised in the Task Force (1996) HRV guidelines.",
    "max"       => "Descriptive primitive of the Task Force (1996) time-domain panel.",
    "min"       => "Descriptive primitive of the Task Force (1996) time-domain panel.",
    "range"     => "Descriptive primitive of the Task Force (1996) time-domain panel.",
    "sdnn"      => "Kleiger et al. (1987) established SDNN as the prognostic 24-h HRV index and popularised it; standardised by the Task Force (1996). Primacy contested: Wolf et al. (1978) had already linked a cruder RR-interval SD/variance measure to lower post-MI hospital mortality nearly a decade earlier.",
    "sdann"     => "SDANN (SD of 5-min mean NN), Kleiger et al. (1987); standardised by the Task Force (1996). Primacy contested: Wolf et al. (1978) reported the prognostic RR-variability/post-MI-mortality link that SDANN-family measures build on, predating Kleiger by ~9 years.",
    "sdsd"      => "SD of successive differences, Task Force (1996) short-term panel. Successive-difference HRV measures predate the Task Force standard: Ewing et al. (1984) used them clinically, and the underlying statistic traces to von Neumann's (1941) mean-square successive difference (not independently on file here).",
    "rmssd"     => "Task Force (1996) consensus short-term vagal index. Successive-difference HRV measures predate the Task Force standard: Ewing et al. (1984) used them clinically, and the underlying statistic traces to von Neumann's (1941) mean-square successive difference (not independently on file here).",
    "pnn50"     => "Ewing et al. (1984) introduced the NN50 count; pNN50 was formalised by the Task Force (1996).",
    "pnn20"     => "Mietus et al. (2002), \"The pNNx files\" — generalised the pNNx family including pNN20.",
    "cvnni"     => "Coefficient of variation of NN (SDNN/mean), Task Force (1996).",
    "cvsd"      => "CV of successive differences (RMSSD/mean), Task Force (1996).",
    "rRR"       => "Vollmer (2015) — a robust, simple relative-RR measure of HRV.",
    "mean_hr"   => "BPM re-expression of the Task Force (1996) time-domain panel.",
    "std_hr"    => "BPM re-expression of the Task Force (1996) time-domain panel.",
    "max_hr"    => "BPM re-expression of the Task Force (1996) time-domain panel.",
    "min_hr"    => "BPM re-expression of the Task Force (1996) time-domain panel.",
    "median_hr" => "BPM re-expression of the Task Force (1996) time-domain panel.",
    "range_hr"  => "BPM re-expression of the Task Force (1996) time-domain panel.",
    "ulf"       => "Ultra-low-frequency 1/f power-law scaling, Bigger et al. (1996); band per Task Force (1996); Lomb (1976) least-squares periodogram estimator.",
    "vlf"       => "Akselrod et al. (1981) seminal HRV power-spectrum paper; band per Task Force (1996); Scargle (1982) unevenly-sampled spectral estimator.",
    "lf"        => "Akselrod et al. (1981) / Task Force (1996) LF band (0.04–0.15 Hz); Moody (1993) applied the least-squares periodogram to un-resampled HR.",
    "hf"        => "Akselrod et al. (1981) / Task Force (1996) HF band (0.15–0.4 Hz), the respiratory-sinus-arrhythmia band.",
    "tp"        => "Total power, Akselrod et al. (1981) / Task Force (1996); Welch (1967) periodogram averaging for the resampled backend.",
    "lf_peak"       => "Peak frequency of the LF band, Task Force (1996).",
    "hf_peak"       => "Peak frequency of the HF band, Task Force (1996).",
    "lf_hf_ratio"   => "Pagani et al. (1986) introduced the LF/HF ratio as a marker of sympatho-vagal interaction; standardised by the Task Force (1996) (interpret with care).",
    "lf_relative"   => "LF power in normalised units (fraction of total power), Task Force (1996).",
    "hf_relative"   => "HF power in normalised units (fraction of total power), Task Force (1996).",
    "lf_percentage" => "LF power as a percentage of total power, Task Force (1996).",
    "hf_percentage" => "HF power as a percentage of total power, Task Force (1996).",
    "sd1"              => "Tulppo et al. (1996) introduced ellipse-fitted SD1; Brennan et al. (2001) derived the closed form linking it to SDSD (primacy contested).",
    "sd2"              => "Tulppo et al. (1996) introduced ellipse-fitted SD2; Brennan et al. (2001) derived the closed form linking it to SDNN/SDSD (primacy contested).",
    "sd2_sd1"          => "SD2/SD1 ratio, Tulppo et al. (1996); the \"cardiac sympathetic index\" (CSI) framing is Toichi et al. (1997) (contested naming).",
    "sd1_sd2_area"     => "Poincaré ellipse area π·SD1·SD2, Brennan et al. (2001); Task Force (1996) geometric methods.",
    "cvi"              => "Cardiac vagal index (log₁₀ 16·SD1·SD2), Toichi et al. (1997).",
    "ccsi"             => "Modified / corrected CSI = 4·SD2²/SD1, Jeppesen et al. (2014), Lorenz-plot seizure detection.",
    "triangular_index" => "HRV triangular index, Malik et al. (1989); standardised by the Task Force (1996).",
    "tinn"             => "Triangular Interpolation of the NN histogram (TINN), Malik et al. (1989) / Task Force (1996).",
    "apen"    => "Approximate entropy, Pincus (1991), PNAS.",
    "sampen"  => "Sample entropy, Richman & Moorman (2000), correcting ApEn's self-match bias.",
    "fuzzyen" => "Fuzzy entropy, Chen et al. (2007), replacing SampEn's hard threshold with a fuzzy membership.",
    "shan_en" => "Shannon entropy of the RR histogram, Shannon (1948).",
    "svd_en"  => "SVD (singular-spectrum) entropy, Roberts, Penny & Rezek (1999).",
    "spec_en" => "Spectral entropy (Shannon entropy of the normalised power spectrum), Inouye et al. (1991).",
    "perm_en" => "Permutation entropy, Bandt & Pompe (2002), an ordinal-pattern complexity measure.",
    "mse"     => "Multiscale entropy, Costa, Goldberger & Peng (2002), SampEn across coarse-grained scales.",
    "renyi0"  => "Rényi generalised entropy of order α=0 (log support size), Rényi (1961).",
    "renyi1"  => "Rényi generalised entropy of order α=1 (→ Shannon entropy), Rényi (1961).",
    "renyi2"  => "Rényi generalised entropy of order α=2 (collision entropy), Rényi (1961).",
    "dfa2"    => "Long-term scaling exponent α2, Peng et al. (1995); DFA algorithm, Peng et al. (1994); window convention Francis et al. (2002); age-related range Iyengar et al. (1996).",
    "hurst"   => "Hurst exponent via rescaled-range (R/S) analysis, Hurst (1951).",
)

# ── Curated per-feature use-cases (modest, well-established; falls back to the
#    domain template in make_entry.jl when a feature is absent here) ──────────
const USE_CASES = Dict{String,String}(
    "rmssd" => "- Beat-to-beat parasympathetic (vagal) tone; the most-used short-term HRV index.\n" *
               "- Ultra-short (≥10 s–1 min) and paced-breathing biofeedback targets.\n" *
               "- Daily readiness, recovery, and training-load monitoring.",
    "sdnn" => "- Overall HRV magnitude; prognostic index after myocardial infarction (Kleiger et al. 1987).\n" *
              "- Standard summary of a 24-h or 5-min recording.\n" *
              "- Global autonomic-variability screening.",
    "sdann" => "- Long-term (circadian, ≥5-min) variability component over 24-h recordings.\n" *
               "- Complements SDNN by isolating slow, between-segment drift.\n" *
               "- Prognostic Holter-based risk stratification.",
    "sdsd" => "- Short-term variability from successive differences (closely tracks RMSSD/SD1).\n" *
              "- Vagal-tone screening on short segments.\n" *
              "- Preprocessing sanity check against RMSSD.",
    "pnn50" => "- Parasympathetic activity via the fraction of large beat-to-beat changes.\n" *
               "- Robust, interpretable vagal marker in ambulatory recordings.\n" *
               "- Screening for reduced HRV.",
    "pnn20" => "- More sensitive successive-difference count for low-variability or short records.\n" *
               "- Vagal-tone screening where pNN50 saturates near zero.\n" *
               "- Part of the generalised pNNx family (Mietus et al. 2002).",
    "cvsd" => "- Heart-rate-normalised short-term variability (RMSSD / mean NN).\n" *
              "- Comparing vagal tone across subjects with different baseline rates.\n" *
              "- Recovery / stress monitoring insensitive to mean HR.",
    "cvnni" => "- Heart-rate-normalised overall variability (SDNN / mean NN).\n" *
               "- Cross-subject comparison of HRV magnitude.\n" *
               "- Exploratory screening independent of baseline heart rate (descriptive ratio," *
               " not a validated diagnostic threshold on file).",
    "mean" => "- Baseline heart period; denominator for normalised HRV indices.\n" *
              "- Resting-state and intervention comparisons.\n" *
              "- Sanity check on preprocessing / artifact removal.",
    "rRR" => "- Artifact-robust HRV summary from relative RR intervals (Vollmer 2015).\n" *
             "- Field / wearable recordings with occasional ectopy or noise.\n" *
             "- Complements SDNN/RMSSD when data quality is uncertain.",
    "vlf" => "- Slow (0.003–0.04 Hz) rhythms linked to thermoregulation, renin–angiotensin, and physical activity.\n" *
             "- Longer recordings (≥5 min, ideally hours) where the band resolves.\n" *
             "- Prognostic marker in cardiac risk studies.",
    "lf" => "- Mixed sympathetic/parasympathetic and baroreflex-mediated 0.04–0.15 Hz rhythms.\n" *
            "- Baroreflex and blood-pressure-coupling studies.\n" *
            "- Interpret in normalised units rather than as pure \"sympathetic\" power.",
    "hf" => "- Respiratory sinus arrhythmia; a spectral index of vagal (parasympathetic) tone.\n" *
            "- Paced-breathing and respiratory-coupling studies.\n" *
            "- Vagal-withdrawal detection under stress.",
    "tp" => "- Overall spectral variance across HRV bands.\n" *
            "- Global variability summary alongside SDNN.\n" *
            "- Denominator for normalised / percentage band powers.",
    "lf_hf_ratio" => "- Heuristic \"sympathovagal balance\" summary (interpret with caution).\n" *
                     "- Tracking within-subject shifts between conditions.\n" *
                     "- Report with the component LF and HF powers, not alone.",
    "lf_peak" => "- Centre frequency of the baroreflex-related LF oscillation (~0.1 Hz).\n" *
                 "- Resonance-frequency biofeedback and paced-breathing studies.\n" *
                 "- Spectral-quality check on the LF band.",
    "hf_peak" => "- Centre frequency of the respiratory (HF) oscillation.\n" *
                 "- Cross-checking the HF band against respiration rate.\n" *
                 "- Detecting respiratory frequency from RR alone.",
    "sd1" => "- Short-term Poincaré-plot width; equals RMSSD/√2, a vagal marker.\n" *
             "- At-a-glance geometric read of beat-to-beat variability.\n" *
             "- Robust-to-artifact summary for noisy field recordings.",
    "sd2" => "- Long-term Poincaré-plot length; overall/continuous variability.\n" *
             "- Paired with SD1 for the SD2/SD1 shape ratio.\n" *
             "- Geometric complement to SDNN.",
    "sd2_sd1" => "- Poincaré shape ratio (a.k.a. cardiac sympathetic index).\n" *
                 "- Balance of long- vs short-term variability at a glance.\n" *
                 "- Exploratory autonomic-function screening (e.g. Jeppesen et al. 2014 for seizure" *
                 " detection via the related `ccsi`); treat as a descriptive ratio, not a" *
                 " validated diagnostic marker without a disease-specific study.",
    "sd1_sd2_area" => "- Total Poincaré-ellipse dispersion (π·SD1·SD2).\n" *
                      "- Compact geometric summary of overall variability.\n" *
                      "- Robust-to-artifact field-recording summary.",
    "cvi" => "- Cardiac vagal index from Lorenz-plot geometry (Toichi et al. 1997).\n" *
             "- Parasympathetic-tone screening alongside CSI.\n" *
             "- Autonomic-function assessment.",
    "ccsi" => "- Modified cardiac sympathetic index (4·SD2²/SD1) emphasising long-term spread.\n" *
              "- Lorenz-plot seizure detection (Jeppesen et al. 2014).\n" *
              "- Exploratory autonomic-surge screening (no dedicated validation study on file" *
              " beyond the seizure-detection setting above; use cautiously).",
    "triangular_index" => "- Geometric, artifact-robust overall-HRV magnitude from the RR histogram.\n" *
                          "- 24-h Holter analysis where noise defeats SDNN.\n" *
                          "- Post-MI risk stratification (Malik et al. 1989).",
    "tinn" => "- Baseline width of the triangular RR-histogram interpolation.\n" *
              "- Geometric variability summary robust to outliers.\n" *
              "- Companion to the triangular index.",
    "apen" => "- Regularity / predictability of the RR series (Pincus 1991).\n" *
              "- Discriminating pathological from healthy dynamics (use adequate N).\n" *
              "- Note the self-match bias — prefer SampEn when possible.",
    "sampen" => "- Bias-corrected regularity measure (Richman & Moorman 2000).\n" *
                "- Distinguishing CHF / AF from healthy dynamics.\n" *
                "- Preferred over ApEn for short records.",
    "fuzzyen" => "- Smoother, more consistent complexity estimate than SampEn on short/noisy records.\n" *
                 "- Robustness to parameter and threshold choice.\n" *
                 "- Nonlinear autonomic-control research.",
    "mse" => "- Complexity across time scales, separating rich dynamics from white noise.\n" *
             "- Ageing and disease loss-of-complexity studies (Costa et al. 2002).\n" *
             "- Requires longer records for the coarse scales.",
    "perm_en" => "- Ordinal-pattern complexity; fast and robust to monotone transforms.\n" *
                 "- Noisy-signal complexity screening.\n" *
                 "- Detecting dynamical change / regime shifts.",
    "spec_en" => "- Flatness of the RR power spectrum (peaked vs broadband).\n" *
                 "- Complement to band-power spectral analysis.\n" *
                 "- Autonomic-state discrimination.",
    "shan_en" => "- Information content / spread of the RR-interval distribution.\n" *
                 "- Baseline complexity reference.\n" *
                 "- Building block for other entropy measures.",
    "svd_en" => "- Complexity of the embedded RR trajectory via its singular spectrum.\n" *
                "- Dimensionality / structure of the dynamics.\n" *
                "- Nonlinear-dynamics research.",
    "renyi0" => "- Support size of the RR distribution (Hartley/max-entropy limit).\n" *
                "- Tail-sensitive complexity comparisons.\n" *
                "- Part of the Rényi spectrum with renyi1/renyi2.",
    "renyi1" => "- Shannon-equivalent limit of the Rényi entropy spectrum.\n" *
                "- Reference point against renyi0 / renyi2.\n" *
                "- Distribution-spread complexity.",
    "renyi2" => "- Collision entropy, emphasising the most probable RR values.\n" *
                "- Concentration-sensitive complexity comparisons.\n" *
                "- Part of the Rényi spectrum with renyi0/renyi1.",
    "dfa2" => "- Long-term fractal scaling exponent α2 of the RR series (Peng et al. 1995).\n" *
              "- Ageing and cardiac-disease fractal-breakdown studies.\n" *
              "- Report with α1 and adequate record length.",
    "hurst" => "- Long-range dependence / persistence of the RR series (Hurst 1951).\n" *
               "- Fractal-scaling and self-similarity research.\n" *
               "- Cross-check against the DFA exponents.",
)
