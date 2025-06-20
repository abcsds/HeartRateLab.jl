# HeartRateLab

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://abcsds.github.io/HeartRateLab.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://abcsds.github.io/HeartRateLab.jl/dev/)
[![Build Status](https://github.com/abcsds/HeartRateLab.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/abcsds/HeartRateLab.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/abcsds/HeartRateLab.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/abcsds/HeartRateLab.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)


A Julia package for heart rate analysis based on time series of inter-beat intervals (IBIs).

Objective: To provide a comprehensive set of tools for heart rate analysis that leverage the power of julia's high performance computing capabilities, scientific computing libraries, modeling, machine learning, signal processing, and visualization tools.

## README driven development
The following is a list of features that are planned for the package. The list is subject to change as the package evolves.


# Argument

There exist several open source packages that provide heart rate analysis tools. However, most of them are not maintained. The only option we found was the https://github.com/neuropsychology/NeuroKit package, which is a Python package. The only julia package hasen't been updated in 2 years. Our pull prs had no response. Our fork currently provides the best option for heart rate variability analysis in julia. We aim to provide a comprehensive set of tools for heart rate variability analysis that leverage the power of julia's high performance computing capabilities, scientific computing libraries, modeling, machine learning, signal processing, and visualization tools.

This work is the combination of different HRV tools developed along my PhD:
https://github.com/abcsds/hrv python tools for HRV online biofeedback using bluetooth and HR bands.
https://github.com/abcsds/VizHRV visualization tools for in-depth online HRV analysis.
https://github.com/abcsds/HeartRateVariability.jl Maintained fork of LiScI-Lab/HeartRateVariability.jl providing the most comprehensive set of HRV feature extraction tools in julia.

# Abstract
Heart Rate Variability (HRV) analysis involves examining variations in heart Inter-Beat-Intervals (IBIs). These variations can be extracted using various features. The devices for measuring and recording IBIs are one of the most economic and widely available form of biosignal acquisition. Additionally, there exist experimental and clinical evidence that HRV features are related to the autonomic nervous system (ANS) and can be used to assess its state, providing a valuable insight into cognitive processes. However, available tools for HRV analysis are mainly focused on feature extraction as a numeric value, often neglect to model and visualize many features, and fail to communicate the underlying processes. In this work, we present a comprehensive set of tools for HRV analysis: The Free and Open Source (FOSS) package HeartRateLab. It leverages the power of julia's high performance computing capabilities, FOSS scientific computing libraries, modeling, machine learning, signal processing, and visualization tools to provide a complete set of features for HRV extraction, models for data-driven HRV analysis, and visualizations. The package is designed to be used in an offline setting, as a feature extraction library, but can also be used in online settings for teaching, communication, or HRV biofeedback.

# Approach


### Features
- Input:
    - [x] Read and write IBI data from txt
    - [x] Read and write IBI data from WFDB
    - [x] Read XDF files
- Preprocessing:
    - [x] Replace zeros with NaNs
    - [x] Replace biological implausible values with NaNs
    - [x] Replace statistical outliers with NaNs
    - [x] Replace ectopic beats
    - [x] Strip extremes
    - [x] Interpolate NaNs
    - [x] Interpalate  methods: constant, linear, quadratic, cubic, spline, pchip, akima, hermite, lagrange, fourier, poly
    - [x] windowed analysis
- Features:
    - Registry of features
    - Feature type
    - Feature alias
    - Feature sets: Time domain, Frequency domain, Non-linear dynamics, Complexity, Entropy, Dynamics, Geometric, Fractal, Multiscale
    - Call dependencies?
    - Parallel call of features
    - Signal length-based feature selection
- Modeling:
    - Leaky integrate-and-fire model: Büzás, A., Horváth, T., & Dér, A. (2022). A Novel Approach in Heart-Rate-Variability Analysis Based on Modified Poincaré Plots. IEEE Access, 10, 36606–36615. IEEE Access. https://doi.org/10.1109/ACCESS.2022.3162234
    - Van der Pol oscillator: Lopez-Chamorro, F. M., Arciniegas-Mejia, A. F., Imbajoa-Ruiz, D. E., Rosero-Montalvo, P. D., García, P., Castro-Ospina, A. E., Acosta, A., & Peluffo-Ordóñez, D. H. (2018). Cardiac Pulse Modeling Using a Modified van der Pol Oscillator and Genetic Algorithms. In I. Rojas & F. Ortuño (Eds.), Bioinformatics and Biomedical Engineering (pp. 96–106). Springer International Publishing. https://doi.org/10.1007/978-3-319-78723-7_8
    - Lorenz system: Esperer, H. D., Esperer, C., & Cohen, R. J. (2008). Cardiac Arrhythmias Imprint Specific Signatures on Lorenz Plots. Annals of Noninvasive Electrocardiology, 13(1), 44–60. https://doi.org/10.1111/j.1542-474X.2007.00200.x
    - Dynamic Mode Decomposition. Yeh, J.-R., Sun, W.-Z., Shieh, J.-S., & Huang, N. E. (2010). Intrinsic Mode Analysis of Human Heartbeat Time Series. Annals of Biomedical Engineering, 38(4), 1337–1344. https://doi.org/10.1007/s10439-010-9939-z
    - Variational Autoencoder for Ectopic beat detection: yo merengues (NN for Koopman eigenfunctions: https://www.youtube.com/watch?v=JJaxltAN9Ug)
    - Statistical estimation of model parameters: también merengues
    - Populational hierarchical models: tambor
- Visualization:
    - Interactive GLMakie visualizations:
        - NN-time series
        - ΔNN-time series
        - Feature time series
        - Feature distributions
        - Poincare plot
        - Frequency domain
        - LIF phase space given parameters
        - VDP phase space given parameters
        - Lorenz plot given parameters

# Expected outcomes

- An offline HRV analysis tool for fast feature extraction.
- Documented sets of features for HRV analysis.
- Visualizations for HRV analysis.
- A set of models for data-driven HRV analysis.
- *A set of tools for (online) HRV biofeedback.

### Reproducibility
A Dockerfile and a flake.nix are provided to reproduce the development environment and workflow:
```bash
nix run .#build # build development environment docker image
nix run .#test # run tests
nix run # Open the julia REPL
nix run .#act # Test github workflows
```
