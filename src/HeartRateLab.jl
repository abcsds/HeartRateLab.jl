module HeartRateLab
# input.jl
using Base.Filesystem: mktemp
using XDF: XDF

include("input.jl")
include("preprocessing.jl")
include("Frequency.jl")
include("Features.jl")
include("Models/Models.jl")
include("Evaluation.jl")
include("Visualization/Visualization.jl")

# Test power calculation from periodogram
# using Plots
# n = read_txt("test/testdata/example.txt")[1:50] # Compare with HeartRateVariability.jl
# p = plot(n);
# display(p)
# pgram = Frequency.welch(n; method=:quadratic)
# p = plot(pgram.freq, pgram.power, xlabel="Frequency (Hz)", ylabel="Power", title="Welch Periodogram")
# display(p)
# display(plot(pgram.power))
# Frequency.get_power(pgram, 0.003, 0.4)

# infile = "test/testdata/example.txt"
# data = HeartRateLab.Input.read_txt(infile)
# using Input: read_xdf, read_txt, read_wfdb
# using Preprocessing: replace_zeros, replace_bio_outliers, replace_statistical_outliers, replace_ectopic_beats!, replace_ectopic_beats, strip_extremes, interpolate_nans!, interpolate_nans, interpolate, windowed

# export all functions
# for f in names(Features.registry)
#     eval(:(export $f))
# end

# export Input
export read_xdf
export read_txt
export read_wfdb
export Preprocessing
# export Preprocessing
export replace_zeros
export replace_bio_outliers
export replace_statistical_outliers
export replace_ectopic_beats!
export replace_ectopic_beats
export strip_extremes
export interpolate_nans!
export interpolate_nans
export interpolate
export windowed
# Re-export functions from submodules
import .Features: extract_feature_set, windowed_feature_set, valid_features
import .Features: FAST_FEATURES, ALL_FEATURES, NONLINEAR_FEATURES, DEFAULT_FEATURES
import .Features: HRFeature, feature_registry, DISTRIBUTION_MAP
import .Features: prior_registry, normative_prior, prior_call_string, load_normative_priors!
import .Evaluation: simulate_ensemble, extract_ensemble_features, eval_distributional, eval_scalar, eval_distance
import .Evaluation: information_criteria, rank_models, model_loglikelihood, model_n_params, aic, bic
import .Visualization: plot_ibi_series, plot_poincare, plot_spectrum, plot_comparison, plot_model_heatmap, plot_lorenz_3d, plot_radar, plot_correlations, plot_flagship
import .Visualization: plot_normative_kde_comparison, plot_feature_correlogram, plot_normative_pairplot
import .Visualization: plot_lif, plot_dmd, plot_dfa, plot_complexity, plot_time_frequency_3d, plot_poincare_3d
import .Models: VanDerPol, Lorenz, LIF, DMD, AbstractHRVModel, ModelFitResult, simulate, parameter_space, fit, parameter_series, forecast

# export Features
# export lomb_scargle
# export welch
# export get_power
# export get_peaks
export extract_feature_set, windowed_feature_set, valid_features, simulate_ensemble, extract_ensemble_features, eval_distributional, eval_scalar, eval_distance
# Only the high-level ranking API is exported. The building blocks
# (model_loglikelihood/model_n_params/aic/bic) are reachable as
# HeartRateLab.Evaluation.* — `aic`/`bic` deliberately stay unexported because
# they collide with StatsBase's `aic`/`bic` (a transitive dependency).
export information_criteria, rank_models
export FAST_FEATURES, ALL_FEATURES, NONLINEAR_FEATURES, DEFAULT_FEATURES
export HRFeature, feature_registry, DISTRIBUTION_MAP
export prior_registry, normative_prior, prior_call_string, load_normative_priors!
# PhysioNet dataset loaders (load_physionet/load_nsrdb/…) are NOT package API — they were
# only ever defined in the dead ModelsExt. Salvaged to test/tools/dataset_loaders.jl (backlog d-18).
export plot_ibi_series, plot_poincare, plot_spectrum, plot_comparison, plot_model_heatmap, plot_lorenz_3d, plot_radar, plot_correlations, plot_flagship, fit
export plot_normative_kde_comparison, plot_feature_correlogram, plot_normative_pairplot
export plot_lif, plot_dmd, plot_dfa, plot_complexity, plot_time_frequency_3d, plot_poincare_3d
export VanDerPol, Lorenz, LIF, DMD, AbstractHRVModel, ModelFitResult, simulate, parameter_space, parameter_series, forecast
end
