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

### Features
- Input:
    - [x] Read and write IBI data from txt
    - [ ] Read and write IBI data from WFDB
    - [ ] Read XDF files
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
    - Populational hierarchical models: pos quién más, papá?
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
