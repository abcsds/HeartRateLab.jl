# Encoding domain knowledge in Dagger.jl's lazy API using datadeps

Example 1: Simple Lazy Computation Chain

In this first example, we start with a simple dependency chain. You load raw data, compute its mean, calculate its derivative, and finally compute the mean of that derivative. Notice how each transformation is wrapped in a delayed expression (the lazy API) so that the dependency is automatically tracked by the DAG.

```julia
using Dagger

# Assume `load_data` is a function that reads your time series.
data = delayed(load_data, "my_hrv_data.csv")

# Compute the mean of the data
mean_val = delayed(mean, data)

# Compute the derivative (e.g., using diff for simplicity)
deriv = delayed(diff, data)

# Compute the mean of the derivative. This automatically depends on `deriv`.
mean_deriv = delayed(mean, deriv)

# Launch the computation (this gathers the entire DAG)
result = collect(mean_deriv)  # or compute(mean_deriv)
```

Example 2: Multiple Features from the Same Data

Often you want to compute several features from the same input. In this second example we compute the mean, the standard deviation, and the derivative (which in turn is used to compute another mean). This shows how several branches of the DAG can share the same input data.

```julia
using Dagger

data = delayed(load_data, "my_hrv_data.csv")

# Basic statistics features from raw data
mean_val = delayed(mean, data)
std_val  = delayed(std, data)

# Compute derivative and subsequently its mean
deriv    = delayed(diff, data)
mean_deriv = delayed(mean, deriv)

# Materialize results (as needed)
results = collect((mean_val, std_val, mean_deriv))
```

Example 3: Introducing HRV-Specific Computation

For HRV analysis, a common first step is to extract RR intervals from raw ECG data. Once you have the RR intervals, you can compute time-domain features such as SDNN (the standard deviation of the NN intervals). In this example, we introduce an RR interval extraction step, then compute an HRV measure.

```julia
using Dagger

# Step 1: Load ECG signal data
ecg_signal = delayed(load_ecg, "ecg_data.csv")

# Step 2: Extract RR intervals (a function specific to HRV analysis)
rr_intervals = delayed(extract_rr_intervals, ecg_signal)

# Step 3: Compute the standard deviation (SDNN) as an HRV feature
sdnn = delayed(std, rr_intervals)

# Materialize the HRV feature
hrv_feature = collect(sdnn)
```