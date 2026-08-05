# HRV Feature Inventory (Pokédex index)

!!! note "Auto-generated"
    This table is generated from `src/Features.jl` docstrings merged with the fitted
    normative priors in `docs/normative_priors.csv`. Do not edit by hand -- regenerate
    with `docs/zoo_gen/gen_inventory.py`.

**53 user-facing features** (64 `@register function` declarations minus 11 internal representations, e.g. `diff`/`pgram`/`px`/`histogram`/`dfa`).
Domain split: **20 time**, **12 frequency**, **8 geometric**, **13 nonlinear**.
**36** features have a fitted normative prior *and* a column in the NSR2DB windowed
feature table (`test/testdata/nsr2db/windowed_w360_s120_features.csv`); the remaining
**17** (HR spread, ULF, all entropies, DFA-alpha2) are declared but were not windowed/fitted.

| Feature | Domain | Dist. family | Fitted prior | Normal-plot data? | Definition |
|---------|--------|--------------|--------------|-------------------|------------|
| `mean` <br><sub>`average`, `mean_rr`, `mean_nn`</sub> | time | Normal | Normal(778.072, 143.707) | yes (nsr2db) | Mean inter-beat interval |
| `sdnn` <br><sub>`std`</sub> | time | Gamma | Gamma(4.01919, 13.1164) | yes (nsr2db) | Standard deviation of NN intervals |
| `median` <br><sub>`median`</sub> | time | Normal | Normal(778.572, 146.874) | yes (nsr2db) | Median inter-beat interval |
| `max` <br><sub>`max`, `maximum_rr`, `maximum_nn`</sub> | time | Normal | Normal(950.533, 196.306) | yes (nsr2db) | Maximum inter-beat interval |
| `min` <br><sub>`min`, `minimum_rr`, `minimum_nn`</sub> | time | Normal | Normal(627.069, 126.23) | yes (nsr2db) | Minimum inter-beat interval |
| `mean_hr` <br><sub>`mean_hr`, `average_hr`</sub> | time | Normal | Normal(79.7801, 14.8552) | yes (nsr2db) | Mean heart rate |
| `std_hr` <br><sub>`std_hr`</sub> | time | Gamma | Gamma(3.92275, 377.184) | yes (nsr2db) | Standard deviation of heart rate |
| `max_hr` <br><sub>`max_hr`, `maximum_hr`</sub> | time | Normal | Normal(65.782, 13.5154) | yes (nsr2db) | Maximum heart rate |
| `min_hr` <br><sub>`min_hr`, `minimum_hr`</sub> | time | Normal | Normal(99.6572, 20.5263) | yes (nsr2db) | Minimum heart rate |
| `median_hr` <br><sub>`median_hr`</sub> | time | Normal | -- (not fitted) | no column | Calculate the median heart rate in BPM from the Inter-Beat-Intervals (IBIs). |
| `range_hr` <br><sub>`range_hr`, `hr_range`</sub> | time | Gamma | -- (not fitted) | no column | Calculate the range (max − min) of the instantaneous heart rate in BPM. |
| `sdsd` <br><sub>`sdsd`</sub> | time | Gamma | Gamma(2.69983, 12.1921) | yes (nsr2db) | Standard deviation of successive differences |
| `range` <br><sub>`range`</sub> | time | Gamma | Gamma(3.62002, 89.3544) | yes (nsr2db) | Range of inter-beat intervals |
| `rmssd` <br><sub>`rmssd`</sub> | time | Gamma | Gamma(2.70004, 12.1746) | yes (nsr2db) | Root mean square of successive differences |
| `sdann` <br><sub>`sdann`</sub> | time | Gamma | Gamma(0.869538, 27.9356) | yes (nsr2db) | Standard deviation of 5-min average NN intervals |
| `pnn50` <br><sub>`pnn50`</sub> | time | Beta | Beta(0.427202, 10.3405) | yes (nsr2db) | Proportion of successive differences > 50 ms |
| `pnn20` <br><sub>`pnn20`</sub> | time | Beta | Beta(2.63966, 12.5486) | yes (nsr2db) | Proportion of successive differences > 20 ms |
| `cvsd` <br><sub>`cvsd`</sub> | time | Gamma | Gamma(3.20435, 0.0130001) | yes (nsr2db) | Coefficient of variation of successive differences |
| `cvnni` <br><sub>`cvnni`, `cv_nni`, `coefficient_of_variation`</sub> | time | Normal | -- (not fitted) | no column | Calculate the coefficient of variation of the NN intervals (SDNN / mean). |
| `rRR` <br><sub>`rRR`</sub> | time | Gamma | Gamma(4.62985, 0.784604) | yes (nsr2db) | Median relative RR interval distance |
| `ulf` <br><sub>`ultra_low_frequency`</sub> | frequency | Gamma | -- (not fitted) | no column | Ultra-low frequency power (0-0.003 Hz) |
| `vlf` <br><sub>`very_low_frequency`</sub> | frequency | Gamma | Gamma(1.23977, 891.757) | yes (nsr2db) | Very low frequency power (0.003-0.04 Hz) |
| `lf` <br><sub>`low_frequency`</sub> | frequency | Gamma | Gamma(0.870894, 705.956) | yes (nsr2db) | Low frequency power (0.04-0.15 Hz) |
| `hf` <br><sub>`high_frequency`</sub> | frequency | Gamma | Gamma(0.691591, 460.854) | yes (nsr2db) | High frequency power (0.15-0.4 Hz) |
| `tp` <br><sub>`total_power`</sub> | frequency | Gamma | Gamma(0.996483, 1524.91) | yes (nsr2db) | Total power (0.003-0.4 Hz) |
| `lf_peak` <br><sub>`lf_peak`</sub> | frequency | Normal | Normal(0.0643586, 0.0182054) | yes (nsr2db) | Peak frequency in LF band |
| `hf_peak` <br><sub>`hf_peak`</sub> | frequency | Normal | Normal(0.212262, 0.0625479) | yes (nsr2db) | Peak frequency in HF band |
| `lf_hf_ratio` <br><sub>`lf_hf_ratio`</sub> | frequency | LogNormal | LogNormal(0.858276, 0.856713) | yes (nsr2db) | LF/HF power ratio |
| `lf_relative` <br><sub>`lf_relative_power`</sub> | frequency | Beta | Beta(5.29794, 8.29489) | yes (nsr2db) | LF power as proportion of total power |
| `hf_relative` <br><sub>`hf_relative_power`</sub> | frequency | Beta | Beta(1.3594, 5.70271) | yes (nsr2db) | HF power as proportion of total power |
| `lf_percentage` <br><sub>`lf_%`</sub> | frequency | Gamma | Gamma(8.90829, 4.37525) | yes (nsr2db) | LF power as percentage of total power |
| `hf_percentage` <br><sub>`hf_%`</sub> | frequency | Gamma | Gamma(2.53548, 7.59191) | yes (nsr2db) | HF power as percentage of total power |
| `sd1` <br><sub>`sd1`, `sd1_width`</sub> | geometric | Gamma | Gamma(2.69983, 8.62112) | yes (nsr2db) | Poincare plot short-term variability |
| `sd2` <br><sub>`sd2`, `sd2_length`</sub> | geometric | Gamma | Gamma(3.86522, 17.9922) | yes (nsr2db) | Poincare plot long-term variability |
| `sd2_sd1` <br><sub>`sd2_sd1_ratio`, `csi`, `cardiac_sympathetic_index`</sub> | geometric | LogNormal | LogNormal(1.15613, 0.525657) | yes (nsr2db) | Ratio of SD2 to SD1 (cardiac sympathetic index) |
| `sd1_sd2_area` <br><sub>`poincare_area`</sub> | geometric | LogNormal | LogNormal(8.20271, 0.977151) | yes (nsr2db) | Poincare plot ellipse area |
| `cvi` <br><sub>`cardiac_vagal_index`</sub> | geometric | Normal | Normal(4.26936, 0.424368) | yes (nsr2db) | Cardiac vagal index |
| `ccsi` <br><sub>`corrected_cardiac_sympathetic_index`, `corrected_csi`, `modified_csi`</sub> | geometric | LogNormal | LogNormal(6.64948, 0.878659) | yes (nsr2db) | Corrected cardiac sympathetic index |
| `triangular_index` <br><sub>`triangular_index`</sub> | geometric | Gamma | Gamma(6.10767, 1.68813) | yes (nsr2db) | HRV triangular index |
| `tinn` <br><sub>`triangular_interpolation_of_nn_intervals`</sub> | geometric | Gamma | Gamma(5.39762, 30.5632) | yes (nsr2db) | Triangular interpolation of NN interval histogram |
| `apen` <br><sub>`approximate_entropy`, `apen`</sub> | nonlinear | Normal | -- (not fitted) | no column | Approximate entropy |
| `sampen` <br><sub>`sample_entropy`, `sampen`</sub> | nonlinear | Normal | -- (not fitted) | no column | Sample entropy |
| `hurst` <br><sub>`hurst_exponent`, `hurst`</sub> | nonlinear | Beta | -- (not fitted) | no column | Hurst exponent |
| `renyi0` | nonlinear | Normal | -- (not fitted) | no column | Renyi entropy of order 0 |
| `renyi1` | nonlinear | Normal | -- (not fitted) | no column | Renyi entropy of order 1 |
| `renyi2` | nonlinear | Normal | -- (not fitted) | no column | Renyi entropy of order 2 |
| `shan_en` <br><sub>`shannon_entropy`, `shan_en`</sub> | nonlinear | Normal | -- (not fitted) | no column | Calculate the Shannon entropy of the Inter-Beat-Interval histogram. |
| `svd_en` <br><sub>`svd_entropy`, `svd_en`</sub> | nonlinear | Normal | -- (not fitted) | no column | Calculate the Singular Value Decomposition (SVD) entropy of the IBIs: the Shannon |
| `fuzzyen` <br><sub>`fuzzy_entropy`, `fuzzyen`</sub> | nonlinear | Normal | -- (not fitted) | no column | Calculate the fuzzy entropy of the Inter-Beat-Intervals (IBIs). |
| `spec_en` <br><sub>`spectral_entropy`, `spec_en`</sub> | nonlinear | Normal | -- (not fitted) | no column | Calculate the spectral entropy of the Inter-Beat-Intervals (IBIs): the Shannon |
| `perm_en` <br><sub>`permutation_entropy`, `perm_en`</sub> | nonlinear | Normal | -- (not fitted) | no column | Calculate the permutation entropy of the Inter-Beat-Intervals (IBIs). |
| `mse` <br><sub>`multiscale_entropy`, `mse`</sub> | nonlinear | Normal | -- (not fitted) | no column | Calculate the Multiscale Entropy (MSE) complexity index of the IBIs: the summed |
| `dfa2` <br><sub>`dfa2`, `dfa_exponent_2`</sub> | nonlinear | Normal | -- (not fitted) | no column | DFA long-term scaling exponent alpha2 |

See [`rmssd`](rmssd.md) for the reference dex entry.
