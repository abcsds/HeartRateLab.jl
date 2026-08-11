# HRV Feature Inventory (Pokédex index)

!!! note "Auto-generated"
    This table is generated from `src/Features.jl` docstrings merged with the fitted
    normative priors in `docs/normative_priors.csv`. Do not edit by hand -- regenerate
    with `docs/zoo_gen/gen_inventory.py`.

**53 user-facing features** (64 `@register function` declarations minus 11 internal representations, e.g. `diff`/`pgram`/`px`/`histogram`/`dfa`).
Domain split: **20 time**, **12 frequency**, **8 geometric**, **13 nonlinear**.
**52** features have a fitted normative prior *and* a column in the pooled windowed feature tables (`test/testdata/{nsrdb,nsr2db}/windowed_w360_s120_features.csv`, full 53-feature re-extraction).
The exception is `ulf`: a 360-beat (~5 min) window contains no ULF-band power, so its
prior is fitted from a long-window NSRDB-only extraction instead
(`docs/normative_priors_extended.csv`; see its dex page).

| Feature | Domain | Dist. family | Fitted prior | Normal-plot data? | Definition |
|---------|--------|--------------|--------------|-------------------|------------|
| `mean` <br><sub>`average`, `mean_rr`, `mean_nn`</sub> | time | Normal | Normal(779.63, 146.809) | yes (nsr2db) | Mean inter-beat interval |
| `sdnn` <br><sub>`std`</sub> | time | Gamma | Gamma(3.79456, 14.0333) | yes (nsr2db) | Standard deviation of NN intervals |
| `median` <br><sub>`median`</sub> | time | Normal | Normal(780.304, 150.506) | yes (nsr2db) | Median inter-beat interval |
| `max` <br><sub>`max`, `maximum_rr`, `maximum_nn`</sub> | time | Normal | Normal(953.124, 197.422) | yes (nsr2db) | Maximum inter-beat interval |
| `min` <br><sub>`min`, `minimum_rr`, `minimum_nn`</sub> | time | Normal | Normal(624.826, 127.948) | yes (nsr2db) | Minimum inter-beat interval |
| `mean_hr` <br><sub>`mean_hr`, `average_hr`</sub> | time | Normal | Normal(79.7279, 15.1509) | yes (nsr2db) | Mean heart rate |
| `std_hr` <br><sub>`std_hr`</sub> | time | Gamma | Gamma(3.78601, 391.954) | yes (nsr2db) | Standard deviation of heart rate |
| `max_hr` <br><sub>`max_hr`, `maximum_hr`</sub> | time | Normal | Normal(65.6858, 13.7542) | yes (nsr2db) | Maximum heart rate |
| `min_hr` <br><sub>`min_hr`, `minimum_hr`</sub> | time | Normal | Normal(100.179, 21.1027) | yes (nsr2db) | Minimum heart rate |
| `median_hr` <br><sub>`median_hr`</sub> | time | Normal | Normal(79.7865, 15.4792) | yes (nsr2db) | Calculate the median heart rate in BPM from the Inter-Beat-Intervals (IBIs). |
| `range_hr` <br><sub>`range_hr`, `hr_range`</sub> | time | Gamma | Gamma(3.49434, 9.87114) | yes (nsr2db) | Calculate the range (max − min) of the instantaneous heart rate in BPM. |
| `sdsd` <br><sub>`sdsd`</sub> | time | Gamma | Gamma(2.39951, 14.244) | yes (nsr2db) | Standard deviation of successive differences |
| `range` <br><sub>`range`</sub> | time | Gamma | Gamma(3.48969, 94.0767) | yes (nsr2db) | Range of inter-beat intervals |
| `rmssd` <br><sub>`rmssd`</sub> | time | Gamma | Gamma(2.39968, 14.2236) | yes (nsr2db) | Root mean square of successive differences |
| `sdann` <br><sub>`sdann`</sub> | time | Gamma | Gamma(0.872543, 27.8499) | yes (nsr2db) | Standard deviation of 5-min average NN intervals |
| `pnn50` <br><sub>`pnn50`</sub> | time | Beta | Beta(0.321105, 3.56302) | yes (nsr2db) | Proportion of successive differences > 50 ms |
| `pnn20` <br><sub>`pnn20`</sub> | time | Beta | Beta(1.80627, 3.3006) | yes (nsr2db) | Proportion of successive differences > 20 ms |
| `cvsd` <br><sub>`cvsd`</sub> | time | Gamma | Gamma(2.92912, 0.0146017) | yes (nsr2db) | Coefficient of variation of successive differences |
| `cvnni` <br><sub>`cvnni`, `cv_nni`, `coefficient_of_variation`</sub> | time | Normal | Normal(0.0678885, 0.0336782) | yes (nsr2db) | Calculate the coefficient of variation of the NN intervals (SDNN / mean). |
| `rRR` <br><sub>`rRR`</sub> | time | Gamma | Gamma(4.16456, 0.880637) | yes (nsr2db) | Median relative RR interval distance |
| `ulf` <br><sub>`ultra_low_frequency`</sub> | frequency | Gamma | -- (not fitted) | yes (nsr2db) | Ultra-low frequency power (0-0.003 Hz) |
| `vlf` <br><sub>`very_low_frequency`</sub> | frequency | Gamma | Gamma(1.26787, 1016.29) | yes (nsr2db) | Very low frequency power (0.003-0.04 Hz) |
| `lf` <br><sub>`low_frequency`</sub> | frequency | Gamma | Gamma(0.867559, 705.126) | yes (nsr2db) | Low frequency power (0.04-0.15 Hz) |
| `hf` <br><sub>`high_frequency`</sub> | frequency | Gamma | Gamma(0.614778, 586.905) | yes (nsr2db) | High frequency power (0.15-0.4 Hz) |
| `tp` <br><sub>`total_power`</sub> | frequency | Gamma | Gamma(0.946472, 1650.14) | yes (nsr2db) | Total power (0.003-0.4 Hz) |
| `lf_peak` <br><sub>`lf_peak`</sub> | frequency | Normal | Normal(0.0641876, 0.0182836) | yes (nsr2db) | Peak frequency in LF band |
| `hf_peak` <br><sub>`hf_peak`</sub> | frequency | Normal | Normal(0.213043, 0.0632662) | yes (nsr2db) | Peak frequency in HF band |
| `lf_hf_ratio` <br><sub>`lf_hf_ratio`</sub> | frequency | LogNormal | LogNormal(0.852419, 0.869056) | yes (nsr2db) | LF/HF power ratio |
| `lf_relative` <br><sub>`lf_relative_power`</sub> | frequency | Beta | Beta(5.12689, 8.01854) | yes (nsr2db) | LF power as proportion of total power |
| `hf_relative` <br><sub>`hf_relative_power`</sub> | frequency | Beta | Beta(1.31186, 5.4359) | yes (nsr2db) | HF power as proportion of total power |
| `lf_percentage` <br><sub>`lf_%`</sub> | frequency | Gamma | Gamma(8.66396, 4.50156) | yes (nsr2db) | LF power as percentage of total power |
| `hf_percentage` <br><sub>`hf_%`</sub> | frequency | Gamma | Gamma(2.47899, 7.84251) | yes (nsr2db) | HF power as percentage of total power |
| `sd1` <br><sub>`sd1`, `sd1_width`</sub> | geometric | Gamma | Gamma(2.39951, 10.072) | yes (nsr2db) | Poincare plot short-term variability |
| `sd2` <br><sub>`sd2`, `sd2_length`</sub> | geometric | Gamma | Gamma(3.73146, 18.7254) | yes (nsr2db) | Poincare plot long-term variability |
| `sd2_sd1` <br><sub>`sd2_sd1_ratio`, `csi`, `cardiac_sympathetic_index`</sub> | geometric | LogNormal | LogNormal(1.14433, 0.533233) | yes (nsr2db) | Ratio of SD2 to SD1 (cardiac sympathetic index) |
| `sd1_sd2_area` <br><sub>`poincare_area`</sub> | geometric | LogNormal | LogNormal(8.21388, 1.01145) | yes (nsr2db) | Poincare plot ellipse area |
| `cvi` <br><sub>`cardiac_vagal_index`</sub> | geometric | Normal | Normal(4.27421, 0.439263) | yes (nsr2db) | Cardiac vagal index |
| `ccsi` <br><sub>`corrected_cardiac_sympathetic_index`, `corrected_csi`, `modified_csi`</sub> | geometric | LogNormal | LogNormal(6.63737, 0.881501) | yes (nsr2db) | Corrected cardiac sympathetic index |
| `triangular_index` <br><sub>`triangular_index`</sub> | geometric | Gamma | Gamma(5.93731, 1.7368) | yes (nsr2db) | HRV triangular index |
| `tinn` <br><sub>`triangular_interpolation_of_nn_intervals`</sub> | geometric | Gamma | Gamma(5.32111, 30.9077) | yes (nsr2db) | Triangular interpolation of NN interval histogram |
| `apen` <br><sub>`approximate_entropy`, `apen`</sub> | nonlinear | Normal | Normal(0.76058, 0.271134) | yes (nsr2db) | Approximate entropy |
| `sampen` <br><sub>`sample_entropy`, `sampen`</sub> | nonlinear | Normal | Normal(2.03618, 0.487912) | yes (nsr2db) | Sample entropy |
| `hurst` <br><sub>`hurst_exponent`, `hurst`</sub> | nonlinear | Beta | Beta(2.88321, 6.16953) | yes (nsr2db) | Hurst exponent |
| `renyi0` | nonlinear | Normal | Normal(-6.6412, 0.188067) | yes (nsr2db) | Renyi entropy of order 0 |
| `renyi1` | nonlinear | Normal | Normal(-6.64408, 0.188407) | yes (nsr2db) | Renyi entropy of order 1 |
| `renyi2` | nonlinear | Normal | Normal(-6.64689, 0.188699) | yes (nsr2db) | Renyi entropy of order 2 |
| `shan_en` <br><sub>`shannon_entropy`, `shan_en`</sub> | nonlinear | Normal | Normal(2.99729, 0.467196) | yes (nsr2db) | Calculate the Shannon entropy of the Inter-Beat-Interval histogram. |
| `svd_en` <br><sub>`svd_entropy`, `svd_en`</sub> | nonlinear | Normal | Normal(0.138612, 0.0717375) | yes (nsr2db) | Calculate the Singular Value Decomposition (SVD) entropy of the IBIs: the Shannon |
| `fuzzyen` <br><sub>`fuzzy_entropy`, `fuzzyen`</sub> | nonlinear | Normal | Normal(2.1431, 0.410644) | yes (nsr2db) | Calculate the fuzzy entropy of the Inter-Beat-Intervals (IBIs). |
| `spec_en` <br><sub>`spectral_entropy`, `spec_en`</sub> | nonlinear | Normal | Normal(0.162702, 0.00570936) | yes (nsr2db) | Calculate the spectral entropy of the Inter-Beat-Intervals (IBIs): the Shannon |
| `perm_en` <br><sub>`permutation_entropy`, `perm_en`</sub> | nonlinear | Normal | Normal(2.45234, 0.0726223) | yes (nsr2db) | Calculate the permutation entropy of the Inter-Beat-Intervals (IBIs). |
| `mse` <br><sub>`multiscale_entropy`, `mse`</sub> | nonlinear | Normal | Normal(5.24064, 1.48051) | yes (nsr2db) | Calculate the Multiscale Entropy (MSE) complexity index of the IBIs: the summed |
| `dfa2` <br><sub>`dfa2`, `dfa_exponent_2`</sub> | nonlinear | Normal | Normal(0.974937, 0.249794) | yes (nsr2db) | DFA long-term scaling exponent alpha2 |

See [`rmssd`](rmssd.md) for the reference dex entry.
