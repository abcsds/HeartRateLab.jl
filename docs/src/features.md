# Heart Rate Variability Features

HeartRateLab extracts **53 HRV features** across **4 analysis domains** from inter-beat-interval (IBI) time series data.

## Feature Domains

### 1. Time Domain (10 features)
Statistical measures of IBI variations:

- **Mean IBI** - Average inter-beat-interval
- **Heart Rate** - Mean heart rate in beats per minute
- **Std RR** - Standard deviation of RR-intervals
- **CV RR** - Coefficient of variation
- **RMSSD** - Root mean square of successive differences
- **pNN50** - Percentage of successive intervals > 50ms
- **pNN20** - Percentage of successive intervals > 20ms
- **Median RR** - Median RR-interval
- **Min RR / Max RR** - Range of RR-intervals

### 2. Frequency Domain (8 features)
Power spectral characteristics:

- **VLF Power** - Very Low Frequency (0.0-0.04 Hz)
- **LF Power** - Low Frequency (0.04-0.15 Hz)
- **HF Power** - High Frequency (0.15-0.4 Hz)
- **Total Power** - Sum of VLF, LF, HF
- **VLF/HF Ratio** - Sympathovagal balance indicator
- **LF/HF Ratio** - ANS activity measure
- **LF norm** - Normalized LF power
- **HF norm** - Normalized HF power

### 3. Poincaré Plot (6 features)
Nonlinear scatter plot analysis:

- **SD1** - Perpendicular std dev (short-term variability)
- **SD2** - Along-diagonal std dev (long-term variability)
- **SD1/SD2** - Ratio of short to long-term variability
- **Area** - Area of ellipse in Poincaré plot
- **CSI** - Cardiac Sympathetic Index
- **CVI** - Cardiac Vagal Index

### 4. Nonlinear Dynamics (8 features)
Complex system analysis:

- **ApEn** - Approximate Entropy
- **SampEn** - Sample Entropy
- **Fuzzy En** - Fuzzy Entropy
- **Permutation En** - Permutation Entropy
- **Dispersion En** - Dispersion Entropy
- **Shannon En** - Shannon Entropy
- **Tsallis En** - Tsallis Entropy
- **Renyi En** - Rényi Entropy

### 5. Fractal/Complexity (5 features)
Self-similar structure analysis:

- **DFA α₁** - Detrended Fluctuation Analysis (short-term, 4-16ms)
- **DFA α₂** - Detrended Fluctuation Analysis (long-term, 16-64ms)
- **Lyapunov Exponent** - Rate of trajectory divergence
- **Hurst Exponent** - Long-range correlation measure
- **Lempel-Ziv Complexity** - Algorithmic complexity

### 6. Wavelet (4 features)
Time-frequency analysis:

- **Total Wavelet Energy** - Sum of wavelet coefficients
- **Wavelet Energy by Band** - VLF, LF, HF bands
- **Wavelet Entropy** - Randomness in time-frequency distribution

### 7. Acceleration (2 features)
Beat acceleration analysis:

- **Mean acceleration** - Average first derivative
- **Acceleration entropy** - Entropy of beat acceleration

### 8. Geometric (3 features)
Histogram-based measures:

- **TINN** - Triangular interpolation of NN histogram
- **Histogram Width** - Range of histogram
- **Histogram Peak** - Most frequent NN-interval

### 9. Other (6 features)
Additional measures:

- **Variability Index** - Overall HRV magnitude
- **SDSD** - Std dev of successive differences
- **RR_range** - Difference between max and min RR
- **Spectral Edge Frequency** - Frequency containing 95% power
- **Spectral Centroid** - Center of mass of spectrum
- **Spectral Spread** - Spread around spectral centroid

## Feature Extraction

### Basic Usage

```julia
using HeartRateLab

# Load data
ibis = read_txt("data.txt")

# Extract all features
features = extract_feature_set(ibis)

# Extract by domain
time_domain = extract_feature_set(ibis; domains=[:time])
freq_domain = extract_feature_set(ibis; domains=[:frequency])
nonlinear_domain = extract_feature_set(ibis; domains=[:nonlinear])
```

### Signal Length Requirements

Different features require minimum signal lengths:

```julia
# Check valid features for a given signal length
valid = valid_features(length(ibis))

# Features table
# Signal length 10:  11 features
# Signal length 50:  25 features
# Signal length 100: 32 features
# Signal length 128: 53 features (all)
```

### Feature Preprocessing

Features are automatically computed with preprocessing:

```julia
# Preprocessing steps (automatic)
# 1. Replace outliers with NaN
# 2. Interpolate missing values
# 3. Compute features from clean IBI series
# 4. Return NaN for invalid features

# Note: ensure input IBIs are in milliseconds
```

## API Reference

```@autodocs
Modules = [HeartRateLab.Features]
Private = false
```
