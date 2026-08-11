# ─────────────────────────────────────────────────────────────────────────────
# applications.jl — real-world applications literature for the HRV zoo, by
# VARIABLE (expanded from 12 researched measure FAMILIES).
#
# Provenance: each family below was independently (1) researched — read-only
# web literature harvest across clinical / sports-peak-performance /
# meditation-contemplation, verifying every citation against
# Crossref/PubMed/Semantic Scholar/OpenAlex — and (2) adversarially reviewed
# for fabrication/misattribution/overclaim, by the `hrv-applications-
# bibliography` workflow (2026-07). Verdicts ranged SOLID..MAJOR-ISSUES; only
# citations that survived review (or were corrected per the review, e.g.
# `rahman2018` was originally miscredited as "Kuo/Williams") are used here.
#
# Per-study effect statistics (direction, effect size, p-value, DOI, n) live in
# `docs/zoo_gen/effect_stats.csv` (202 rows) — this file is intentionally a
# CONCISE, curated summary (coverage + 1-3 sentence summary + dominant
# direction + up to 4 citation keys) per domain, not a repeat of the raw
# harvest. Family data is shared across every zoo variable in that family;
# `VARIABLE_NOTES` carries a small number of variable-specific
# bibliography-sourced caveats (contested constructs / disputed signs) flagged
# during review.
#
# Consumed by make_entry.jl to render the "## Applications by area" section,
# and by make_index.jl for the per-feature field-coverage facet (`C S P M`).
#
# 2026-08-11 — KB consolidation & citation-expansion: docs/references.bib was
# consolidated with the forecasting + published-RACERS bibliographies and
# citation-expanded via OpenAlex (61 → 543 entries; 89% of the field in one
# connected citation component). The three application domains here map onto
# the KB's field-labeling scheme — clinical · sports & peak-performance ·
# contemplative practice (display name for :meditation) · methods & foundations
# (the seminal map in citations.jl). All curated summaries/refs below predate
# the expansion and survived the 2026-07 adversarial review; the expansion adds
# breadth to the bibliography, it does not alter these verdicts.
# ─────────────────────────────────────────────────────────────────────────────

# coverage ∈ {"statistics", "individual-papers", "sparse-or-none"}
struct DomainApplication
    coverage::String
    summary::String
    direction::String
    refs::Vector{String}   # references.bib keys, 1-4, primary/most load-bearing first
end

# ── Family → {clinical, sports, meditation} ──────────────────────────────────
const FAMILY_APPLICATIONS = Dict{String,NamedTuple}(

    "hr_level" => (
        clinical = DomainApplication(
            "statistics",
            "Elevated resting/mean heart rate is one of the most consistently replicated clinical " *
            "predictors: dose-response meta-analyses pooling dozens of prospective cohorts " *
            "(> 1.2 million subjects) show a near-linear rise in all-cause and cardiovascular " *
            "mortality, coronary heart disease, heart failure and even cancer incidence per +10 bpm. " *
            "Age-predicted HRmax (208 − 0.7·age) is itself a load-bearing exercise-testing constant " *
            "from a 351-study meta-analytic pooling.",
            "up — higher resting HR → higher mortality/CV risk (≈RR 1.08–1.17 per 10 bpm)",
            ["zhang2016", "aune2017", "tanaka2001"],
        ),
        sports = DomainApplication(
            "statistics",
            "Lower resting HR (\"training bradycardia\") and faster post-exercise heart-rate recovery " *
            "(HRR) are classic, meta-analyzed markers of positive training adaptation — but the same " *
            "meta-analysis found faster HRR also accompanies functional overreaching, so the identical " *
            "directional signal reads as both \"good\" and \"bad\" depending on context.",
            "down at rest / faster HRR — but HRR speed alone cannot separate adaptation from overreaching",
            ["bellenger2016"],
        ),
        meditation = DomainApplication(
            "statistics",
            "A 45-RCT meta-analysis finds meditation reduces heart rate overall (concentrated in " *
            "\"open monitoring\" styles), but this is contested: a more recent physiological study found " *
            "HR unchanged or significantly *increased* during Chi/Kundalini-yoga meditation, explicitly " *
            "arguing raw HR is a poor real-time biofeedback signal.",
            "contested — meta-analytic decrease vs. style-specific increase/no-change",
            ["pascoe2017", "natarajan2023"],
        ),
    ),

    "global_variability" => (
        clinical = DomainApplication(
            "statistics",
            "SDNN/SDANN are among the most validated HRV mortality predictors: low values predict " *
            "higher cardiac/all-cause mortality post-MI, in heart failure, and even in the general " *
            "population (8 cohorts, n = 21,988). CVNNI has its own well-established sub-literature as a " *
            "diabetic cardiac autonomic neuropathy screening marker. One acute-decompensated-HF study " *
            "reports the opposite polarity (higher SDNN/SDANN in the poor-prognosis group).",
            "down — low SDNN/SDANN/CVNNI → higher mortality (one acute-HF exception reversed)",
            ["hillebrand2013", "rueda2024"],
        ),
        sports = DomainApplication(
            "individual-papers",
            "Comparatively under-used next to RMSSD in sports HRV monitoring — the field's dedicated " *
            "meta-analysis pools RMSSD/HF/SD1, not SDNN. Individual studies find SDNN falls with heavy " *
            "training/overreaching and recovers during taper, and tends to be higher in higher-level " *
            "athletes, but effect sizes are small-sample and heterogeneous.",
            "down with overreaching, recovers with taper (RMSSD-dominated literature, SDNN secondary)",
            ["bellenger2016"],
        ),
        meditation = DomainApplication(
            "individual-papers",
            "The weakest of the three domains for this family: two dedicated meta-analyses found the " *
            "evidence for resting/vagally-mediated HRV — including SDNN — inconclusive or null, with " *
            "only a handful of trials reporting SDNN at all. Individual acute-state studies diverge " *
            "sharply in direction (SDNN falls during Heartfulness meditation, rises during Chi/" *
            "Kundalini-yoga).",
            "contested — meta-analytic null vs. technique-dependent individual-study increases/decreases",
            ["radmark2019", "brown2021"],
        ),
    ),

    "short_term_vagal" => (
        clinical = DomainApplication(
            "statistics",
            "RMSSD/pNN50 are among the most heavily studied HRV measures in psychiatry: two independent " *
            "meta-analyses converge on significantly reduced RMSSD/pNN50 in major depression vs. " *
            "healthy controls (g ≈ −0.46 to −0.51, thousands of patients pooled), extending to broader " *
            "cardiovascular-risk and mental-disorder populations.",
            "down — reduced in depression/anxiety (g ≈ −0.3 to −0.5)",
            ["koch2019", "wu2023"],
        ),
        sports = DomainApplication(
            "statistics",
            "RMSSD is the dominant, most-meta-analyzed short-term vagal index in sports science for " *
            "training-load, recovery and overreaching monitoring — but its direction under overload is " *
            "genuinely context-dependent: it can rise *or* fall depending on overload type/timing, an " *
            "ambiguity documented across multiple competing meta-analyses rather than settled.",
            "context-dependent — rises with some overreaching patterns, falls with others (pre-competition taper)",
            ["bellenger2016"],
        ),
        meditation = DomainApplication(
            "individual-papers",
            "The one dedicated meta-analysis pooled only 3 studies and found a null RMSSD effect, " *
            "explicitly citing too few large RCTs — yet several individually-reported trials claim " *
            "significant RMSSD/pNN50 increases with practice, the largest reported-vs-pooled gap of the " *
            "three application domains.",
            "contested — meta-analytic null vs. positive individual trials",
            ["radmark2019"],
        ),
    ),

    "geometric" => (
        clinical = DomainApplication(
            "statistics",
            "HTI (and TINN) are original 1996 Task Force geometric measures that remain recurring " *
            "prognostic markers: reduced HTI/TINN is associated with higher post-MI and atrial-" *
            "fibrillation mortality and reduced diabetic autonomic integrity — except one hemodialysis-AF " *
            "cohort reporting a U-shaped, not monotonic, relationship.",
            "down — lower HTI/TINN → worse outcome (one U-shaped exception)",
            ["taskforce1996", "stuckey2014"],
        ),
        sports = DomainApplication(
            "individual-papers",
            "Not the sports-science metric of choice — a 138-athlete profiling study and dedicated " *
            "exercise-HRV meta-analyses bypass HTI/TINN entirely in favor of SDNN/RMSSD/LF-HF. Where it " *
            "is reported, HTI rises with higher aerobic/endurance training status.",
            "up with endurance training status (rarely reported)",
            ["stuckey2014"],
        ),
        meditation = DomainApplication(
            "sparse-or-none",
            "Six targeted searches of the most relevant meditation/mindfulness HRV papers found none " *
            "reporting HTI or TINN — these studies uniformly use SDNN/RMSSD/LF-HF instead, plausibly " *
            "because typical meditation-session recordings (5–20 min) are too short for a stable NN-" *
            "interval histogram (the Task Force recommends ≥20 min, ideally 24 h).",
            "no data harvested for this domain",
            ["taskforce1996"],
        ),
    ),

    "ulf_vlf" => (
        clinical = DomainApplication(
            "statistics",
            "ULF/VLF power is extensively studied in mortality risk stratification: lower ULF/VLF " *
            "consistently predicts higher all-cause/cardiac/arrhythmic mortality post-MI, in CHF, ACS " *
            "and elderly cohorts. A 2024 meta-analysis, however, found time-domain measures (SDNN, HTI) " *
            "the strongest post-MI predictors rather than VLF/ULF specifically, and the band's own " *
            "physiological interpretation (thermoregulation vs. renin–angiotensin vs. artifact) remains " *
            "unsettled.",
            "down — lower ULF/VLF → higher mortality (contested against time-domain predictors)",
            ["shaffer2017", "rueda2024", "yuda2021"],
        ),
        sports = DomainApplication(
            "individual-papers",
            "Uncommon as a headline sports metric. Acute dose-response is consistent and strong " *
            "(ULF/VLF falls monotonically with rising exercise intensity; ambulatory ULF rises sharply " *
            "with movement, largely a motion-artifact/thermoregulatory effect), but chronic-training/" *
            "overtraining findings are weak, inconsistent, and even sex-reversed within a single small " *
            "study.",
            "down acutely with intensity; chronic/training direction unsettled",
            ["shaffer2017"],
        ),
        meditation = DomainApplication(
            "individual-papers",
            "A minor, seldom-isolated component of meditation HRV research: one classic study reports " *
            "dramatic, exaggerated VLF-spanning oscillations tied to extremely slow breathing during " *
            "Chi/Kundalini meditation, while a more careful spectral study found no change in normalized " *
            "VLF power but a significant drop in the residual (non-harmonic) component — illustrating " *
            "strong method-dependence (raw vs. normalized vs. residual power).",
            "method-dependent (raw vs. normalized vs. residual)",
            ["shaffer2017"],
        ),
    ),

    "lf_hf" => (
        clinical = DomainApplication(
            "statistics",
            "LF, HF and total power are consistently reduced in disease states (cardiac mortality risk, " *
            "depression, anxiety, T2DM autonomic neuropathy) across large meta-analyses — but the LF/HF " *
            "*ratio* itself is repeatedly non-significant in the very same datasets where its components " *
            "move significantly, undercutting its billing as the most sensitive \"sympathovagal balance\" " *
            "composite.",
            "down — LF/HF/TP reduced in disease; the LF/HF ratio specifically is often null",
            ["rueda2024", "wu2023", "chalmers2014"],
        ),
        sports = DomainApplication(
            "statistics",
            "Heavily used for training-load/overreaching monitoring, anchored by a 27-study meta-" *
            "analysis; the intuitive \"LF up / HF down under overload\" model is directly contradicted by " *
            "a body of work reporting paradoxical parasympathetic hyperactivity in overreached athletes, " *
            "and the popular LF/HF > 4 \"overtraining\" cutoff is shown to be driven mainly by spontaneous " *
            "breathing frequency rather than training state.",
            "contested — sympathetic-dominance model vs. parasympathetic-hyperactivity counter-evidence, " *
            "confounded by respiration",
            ["bellenger2016"],
        ),
        meditation = DomainApplication(
            "statistics",
            "Commonly measured but shows null-to-mixed effects: the most direct meta-analysis (4 pooled " *
            "trials) found no significant LF/HF change, and a well-powered 10-day mindfulness RCT " *
            "likewise found no HF/LF-HF effect even though RMSSD rose — individual intensive-retreat " *
            "studies show more mixed, technique- and task-dependent patterns confounded by voluntary " *
            "breath-rate change.",
            "null-to-mixed, confounded by breathing",
            ["radmark2019"],
        ),
    ),

    "poincare" => (
        clinical = DomainApplication(
            "statistics",
            "A well-established clinical output across cardiology, endocrinology and psychiatry: lower " *
            "SD1/SD2 (reduced beat-to-beat and long-term variability) consistently marks worse disease " *
            "state, though most reported sample sizes are small (n = 18–95). SD1 is mathematically " *
            "identical to RMSSD (SD1 = RMSSD/√2), so papers reporting both as independently \"significant\" " *
            "double-count the same statistic, and the SD2/SD1 ratio's billing as a \"sympathovagal " *
            "balance\" surrogate is directly contested.",
            "down — lower SD1/SD2 → worse disease state",
            ["ciccone2017", "rahman2018", "stuckey2014"],
        ),
        sports = DomainApplication(
            "individual-papers",
            "Largely restates RMSSD-based vagal-tone monitoring in geometric form (SD1 = RMSSD/√2), plus " *
            "an SD2/SD1 \"stress score\" aimed at overreaching detection; SD1 rises with aerobic training " *
            "and falls with acute intensity/overtraining, though overtraining shows a non-monotonic " *
            "pattern (higher than sedentary, far below trained) and no meta-analysis isolates a " *
            "Poincaré-specific effect size distinct from RMSSD.",
            "up with training, down acutely/with overtraining (same underlying signal as RMSSD)",
            ["bellenger2016", "ciccone2017"],
        ),
        meditation = DomainApplication(
            "individual-papers",
            "A handful of small, likely underpowered studies (n = 8–18) report SD1/SD2-ratio changes " *
            "across meditation traditions, but the direction of SD2 and total Poincaré-plot area " *
            "disagrees between the two studies that report it — exploratory, not established.",
            "inconsistent across the two available small studies",
            ["ciccone2017"],
        ),
    ),

    "csi_cvi" => (
        clinical = DomainApplication(
            "individual-papers",
            "CSI/CVI (Toichi 1997) separates sympathetic/parasympathetic contributions from a single " *
            "short ECG without pharmacological blockade; reported clinical uses include psychiatric " *
            "autonomic dysfunction (CVI drops with worsening psychosis) and epilepsy (CSI spikes " *
            "distinguish epileptic from psychogenic non-epileptic seizures, though the companion CVI " *
            "measure does not discriminate the same comparison).",
            "CSI up / CVI down under acute stress or pathology; the two halves of the index do not always agree",
            ["toichi1997", "jeppesen2014", "jeppesen2016"],
        ),
        sports = DomainApplication(
            "individual-papers",
            "The one on-topic study (elite football) found CVI differs significantly by playing position " *
            "but not between athletes and non-athlete controls as a whole — a weaker, more qualified " *
            "version of the classic \"athletes have higher vagal tone\" story than the RMSSD-based " *
            "literature tells; otherwise CSI/CVI appear mainly in methodological papers illustrating " *
            "exercise/postural-change tracking.",
            "position-dependent; no clear athlete-vs.-control effect at the whole-group level",
            ["toichi1997"],
        ),
        meditation = DomainApplication(
            "sparse-or-none",
            "No study computes CSI/CVI exactly as Toichi (1997) defined them in a meditation/mindfulness/" *
            "yoga-breathing population; the same Poincaré-geometry construct appears in meditation " *
            "studies under other names (SD1/SD2 ratio, ad hoc indices), so the literal CSI/CVI label is " *
            "essentially absent from this domain even though the underlying geometry is well studied.",
            "no data harvested under this name",
            ["toichi1997"],
        ),
    ),

    "apen_sampen" => (
        clinical = DomainApplication(
            "statistics",
            "Commonly used for autonomic-complexity/regularity assessment (diabetic neuropathy, CHF, " *
            "depression, aging mortality); the dominant \"loss of complexity with disease\" narrative is " *
            "*not* universal — several well-cited studies report the opposite (higher/more erratic " *
            "entropy in CHF, higher blood-pressure SampEn predicting higher mortality in a large aging " *
            "cohort), and a 2026 scoping review of 55 studies explicitly withholds a pooled effect size " *
            "due to methodological heterogeneity.",
            "mixed — mostly down (loss of complexity) in disease, reversed in some CHF/BP-signal studies",
            ["yang2026", "richman2000"],
        ),
        sports = DomainApplication(
            "individual-papers",
            "Used only sporadically — a 19-study systematic review of HRV and overtraining in soccer " *
            "found *zero* studies used any nonlinear/entropy index. Where used, reduced entropy/increased " *
            "regularity tracks fatigue and intense training load, and higher resting entropy loosely " *
            "tracks fitness, but samples are small (n = 11–34) and often only descriptive.",
            "down with fatigue/training load (sparse literature)",
            ["yang2026"],
        ),
        meditation = DomainApplication(
            "individual-papers",
            "Most studies report increased entropy/complexity with meditation practice (a \"healthy " *
            "variability\" framing), but effect sizes are frequently small and non-significant in small " *
            "pilots, and at least one apparent SampEn increase disappeared after covariate adjustment; " *
            "no dedicated meta-analysis of entropy in meditation exists.",
            "up (fragile — often non-significant or vanishes on adjustment)",
            ["yang2026"],
        ),
    ),

    "other_entropy" => (
        clinical = DomainApplication(
            "statistics",
            "Genuinely common here: a 2026 PRISMA review found 55 studies (2011–2025) applying fuzzy/" *
            "Shannon/spectral/SVD/permutation/multiscale entropy, concentrated in diabetes, cardiovascular " *
            "disease and neurological conditions, with classification accuracies up to 92.5%. The " *
            "dominant direction is lower entropy/complexity in disease — with one notable reversal " *
            "(higher multiscale entropy predicted incident stroke in atrial fibrillation).",
            "down — lower entropy/complexity in disease (one AF-stroke reversal)",
            ["yang2026"],
        ),
        sports = DomainApplication(
            "individual-papers",
            "Uncommon: no dedicated meta-analyses exist, and a 2025 systematic review of 19 soccer-" *
            "overtraining studies found none used any nonlinear/entropy index at all. The handful of " *
            "small papers that do exist (n = 9–27, sometimes animal models) give mixed directions.",
            "mixed / essentially unstudied",
            ["yang2026"],
        ),
        meditation = DomainApplication(
            "individual-papers",
            "One dedicated review (26 studies) covers Shannon/ApEn/SampEn/permutation/Renyi/multiscale " *
            "entropy in meditation/yoga: most studies report reduced complexity during meditation, but " *
            "this is not unanimous (some report increases, especially multiscale entropy at long scales), " *
            "and effect sizes are frequently small/non-significant.",
            "mostly down, with scale- and measure-dependent exceptions",
            ["deka2023"],
        ),
    ),

    "dfa" => (
        clinical = DomainApplication(
            "statistics",
            "A well-established nonlinear mortality/arrhythmic-risk predictor: reduced short-term scaling " *
            "exponent α1 (loss of fractal structure) predicts higher all-cause, cardiac and especially " *
            "sudden-cardiac mortality across ~25 years of cohort studies, typically outperforming linear " *
            "HRV indices — though a large 2021 pooled analysis (n = 265,291) found substantial redundancy " *
            "with other HRV/HR-dynamics predictors, tempering the \"independent predictor\" framing.",
            "down — lower α1 → higher mortality risk (redundant with, not fully independent of, other HRV predictors)",
            ["sen2018", "yuda2021"],
        ),
        sports = DomainApplication(
            "individual-papers",
            "A recent, rapidly growing niche proposing DFA-α1 as a lab-free proxy for aerobic/anaerobic " *
            "exercise-intensity thresholds; α1 declines from ~1.5 at rest toward ~0.5 near exhaustion with " *
            "very high correlations to gas-exchange thresholds in small samples — but this is an actively " *
            "contested, unsettled research program (a 2025 large-sample validation found poor agreement, " *
            "prompting a published rebuttal).",
            "down with exercise intensity (threshold-detection validity actively disputed)",
            ["gronwald2020", "cassirame2025", "hoos2025"],
        ),
        meditation = DomainApplication(
            "individual-papers",
            "Very sparse, concentrated almost entirely on one small 1999 physiological dataset that has " *
            "since been reanalyzed by different groups reaching *opposite* conclusions about the direction " *
            "of fractal-complexity change during meditation — no reliable dominant direction can be " *
            "asserted.",
            "unresolved — independent reanalyses of the same dataset disagree",
            ["deka2023"],
        ),
    ),

    "hurst" => (
        clinical = DomainApplication(
            "statistics",
            "Commonly and successfully used via DFA's α1 (a robust proxy for the Hurst exponent on short " *
            "non-stationary cardiac records): lower α1 predicts higher mortality/sudden-cardiac-death risk " *
            "across post-MI, heart-failure and elderly cohorts — one of the most replicated nonlinear-HRV " *
            "findings in cardiology, remaining predictive after adjusting for LVEF and conventional " *
            "covariates (pooled MD −0.17, 95% CI [−0.21, −0.13]).",
            "down — lower Hurst/α1 → higher mortality risk",
            ["sen2018"],
        ),
        sports = DomainApplication(
            "individual-papers",
            "Uncommon as \"Hurst exponent\" per se, but moderately active as the DFA-α1 aerobic/" *
            "ventilatory-threshold method: α1 declines from > 1 (correlated) toward ~0.75 at threshold and " *
            "< 0.5 at high intensity, with very high threshold correlations in small samples — an actively " *
            "contested literature (a 2025 large-sample validation found poor agreement, prompting a " *
            "published rebuttal).",
            "down with exercise intensity (threshold-detection validity disputed)",
            ["gronwald2020", "cassirame2025", "hoos2025"],
        ),
        meditation = DomainApplication(
            "individual-papers",
            "Rare but identifiable: a 2023 narrative review synthesizes ≥8 small studies (n = 8–70) mostly " *
            "reporting a *decrease* in the Hurst/DFA scaling exponent during meditation (breakdown of " *
            "long-range correlation), with one notable study reporting the opposite (increase) during " *
            "\"deep meditation\" that the source review does not reconcile.",
            "mostly down, one unreconciled increase",
            ["deka2023"],
        ),
    ),

    # ── dfa2 (long-term α2) — deliberately SEPARATE from "dfa" (short-term α1).
    #    The dedicated DFA mortality/threshold literature is built almost
    #    entirely around α1; where studies additionally measured α2 the
    #    harvest found it thin, weak or explicitly non-significant. Giving
    #    dfa2 its own family (rather than inheriting "dfa") avoids putting an
    #    α1 mortality/threshold claim on the α2 page. Do not overstate α2. ────
    "dfa2" => (
        clinical = DomainApplication(
            "individual-papers",
            "The DFA mortality literature is overwhelmingly about the short-term exponent α1 (`dfa1`); " *
            "where studies additionally measured the long-term exponent α2, evidence " *
            "is thin and inconsistent. One ESRD cohort measured α2 alongside α1 and found it carried *no " *
            "significant* mortality effect once α1 was accounted for; one elderly community cohort " *
            "(LILAC) reported both α1 and α2 associated with mortality without isolating which exponent " *
            "drove the effect. No dedicated α2 meta-analysis or systematic review exists.",
            "weak/mostly null — α2 rarely reaches significance on its own; no independent α2 effect " *
            "size is established in the harvested literature",
            ["sen2018"],
        ),
        sports = DomainApplication(
            "sparse-or-none",
            "The DFA-based aerobic/anaerobic exercise-threshold research program is specifically built " *
            "on the short-term exponent α1 (declining from ~1.5 at rest toward ~0.5 near exhaustion); " *
            "none of the harvested threshold-detection studies isolate α2 as a distinct sports metric, " *
            "so no application evidence was harvested for α2 in this domain.",
            "no data harvested for this domain",
            String[],
        ),
        meditation = DomainApplication(
            "individual-papers",
            "One small study (deep-meditation practitioners) explicitly measured both α1 and α2 and " *
            "reported a contrary, significant *increase* in both during deep meditation; the broader " *
            "meditation-DFA literature synthesized in the review below is otherwise dominated by α1-only " *
            "findings, so this single α2 data point cannot establish a reliable direction.",
            "unresolved — one small study reports an increase; otherwise essentially unstudied",
            ["deka2023"],
        ),
    ),
)

# ── Variable → family key. Variables absent from any harvested family map to
#    the sentinel "none" and get an honest sparse-or-none stub in make_entry. ─
const VARIABLE_FAMILY = Dict{String,String}(
    # time domain
    "mean" => "hr_level", "median" => "hr_level", "max" => "hr_level", "min" => "hr_level",
    "mean_hr" => "hr_level", "max_hr" => "hr_level", "min_hr" => "hr_level",
    "median_hr" => "hr_level",
    "sdnn" => "global_variability", "sdann" => "global_variability",
    "cvnni" => "global_variability", "cvsd" => "global_variability",
    # dispersion/variability measures (std_hr/range_hr/range) belong with
    # sdnn/cvsd — NOT with hr_level (mean/max/min): a variability measure
    # inverts the "higher HR level -> higher mortality" sign (see
    # global_variability's "down -> higher mortality" direction). max_hr/
    # min_hr/max/min stay in hr_level (defensible as HRmax/resting-HR-level
    # markers, not dispersion).
    "std_hr" => "global_variability", "range_hr" => "global_variability",
    "range" => "global_variability",
    "sdsd" => "short_term_vagal", "rmssd" => "short_term_vagal",
    "pnn50" => "short_term_vagal", "pnn20" => "short_term_vagal",
    "rRR" => "none",  # niche 2015 robustness measure; no dedicated applications literature found
    # frequency domain — lf_relative/hf_relative/lf_percentage/hf_percentage are
    # normalized re-expressions of lf/hf reported inside the SAME primary studies.
    "ulf" => "ulf_vlf", "vlf" => "ulf_vlf",
    "lf" => "lf_hf", "hf" => "lf_hf", "tp" => "lf_hf",
    "lf_peak" => "lf_hf", "hf_peak" => "lf_hf", "lf_hf_ratio" => "lf_hf",
    "lf_relative" => "lf_hf", "hf_relative" => "lf_hf",
    "lf_percentage" => "lf_hf", "hf_percentage" => "lf_hf",
    # geometric
    "sd1" => "poincare", "sd2" => "poincare", "sd2_sd1" => "poincare", "sd1_sd2_area" => "poincare",
    "cvi" => "csi_cvi", "ccsi" => "csi_cvi",
    "triangular_index" => "geometric", "tinn" => "geometric",
    # nonlinear
    "apen" => "apen_sampen", "sampen" => "apen_sampen",
    "hurst" => "hurst",
    "renyi0" => "other_entropy", "renyi1" => "other_entropy", "renyi2" => "other_entropy",
    "shan_en" => "other_entropy", "svd_en" => "other_entropy", "fuzzyen" => "other_entropy",
    "spec_en" => "other_entropy", "perm_en" => "other_entropy", "mse" => "other_entropy",
    "dfa1" => "dfa", "dfa2" => "dfa2",
)

# ── Variable-specific bibliography-sourced inconsistency notes (rendered as a
#    `!!! note` callout beneath the Applications section). Multiple notes per
#    variable are allowed (e.g. a construct-validity note AND a sign-dispute
#    note can both apply). ────────────────────────────────────────────────────
const VARIABLE_NOTES = Dict{String,Vector{String}}(
    "sd1" => [
        "**SD1 ≡ RMSSD/√2** — the two are mathematically identical statistics, " *
        "yet much of the clinical/sports literature reports both as independently \"significant\" " *
        "findings, which double-counts the same signal ([ciccone2017](@cite)).",
    ],
    "rmssd" => [
        "**RMSSD ≡ SD1·√2** — see the [`sd1`](sd1.md) entry: papers that report RMSSD and SD1 as " *
        "separate, corroborating findings are re-describing one statistic ([ciccone2017](@cite)).",
        "**Meditation's effect on RMSSD/HR is disputed** — direction of change during meditation is " *
        "not universal across the literature: a meta-analysis and several individual RCTs disagree on " *
        "both the sign and the significance of the RMSSD response (see the Meditation subsection above).",
    ],
    "sd2_sd1" => [
        "**SD2/SD1 as a \"sympathovagal balance\"/CSI surrogate is a contested construct** — its " *
        "bivariate associations with an independent sympathetic marker (pre-ejection period) were small " *
        "and were eliminated after controlling for conventional parasympathetic HRV markers " *
        "([rahman2018](@cite)).",
    ],
    "lf_hf_ratio" => [
        "**LF/HF as \"sympathovagal balance\" is a contested construct** — LF power and the LF/HF ratio " *
        "do not track directly-measured cardiac sympathetic activity, and clinical meta-analyses " *
        "repeatedly find the ratio non-significant even when its LF and HF components individually move " *
        "significantly ([goldstein2011](@cite); [billman2013](@cite)).",
    ],
    "mean" => [
        "**Meditation's effect on HR level is disputed** — a large meta-analysis reports a pooled " *
        "decrease ([pascoe2017](@cite)), but a more recent physiological study found HR unchanged (Chi " *
        "meditation) or significantly *increased* (Kundalini Yoga), explicitly arguing raw HR is a poor " *
        "real-time meditation biofeedback signal ([natarajan2023](@cite)).",
    ],
    "mean_hr" => [
        "**Meditation's effect on HR level is disputed** — see the [`mean`](mean.md) entry: pooled " *
        "meta-analytic decrease ([pascoe2017](@cite)) vs. style-specific increase/no-change " *
        "([natarajan2023](@cite)).",
    ],
    "sdnn" => [
        "**Meditation's effect on SDNN is disputed** — one study found SDRR *decreased* during " *
        "Heartfulness meditation, while another found it *increased* during Chi/Kundalini-yoga " *
        "meditation; both are small, single-technique studies ([natarajan2023](@cite); " *
        "[radmark2019](@cite) for the pooled mindfulness-HRV review these sit alongside).",
    ],
    "dfa2" => [
        "**The strong prognostic DFA evidence in the literature is specific to the short-term " *
        "exponent α1** (`dfa1`) — α2 (long-term) associations are weak, inconsistent, or " *
        "explicitly non-significant in the harvested literature; treat any \"lower DFA exponent → " *
        "higher mortality\" claim you encounter elsewhere as an α1 claim, not an α2 one, unless the " *
        "source specifically isolates α2.",
    ],
)

# ── Lookup helper: returns (coverage_by_domain, notes) for a zoo variable name.
#    Falls back to an honest "no application data harvested" stub for
#    variables not covered by any researched family (e.g. `rRR`, `dfa1`). ─────
function applications_for(name::AbstractString)
    fam = get(VARIABLE_FAMILY, name, "none")
    apps = fam == "none" ? nothing : get(FAMILY_APPLICATIONS, fam, nothing)
    notes = get(VARIABLE_NOTES, name, String[])
    return (family = fam, apps = apps, notes = notes)
end
