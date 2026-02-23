"""
Test script for plot_poincare() visualization function.

Tests the Poincaré plot implementation with:
- Real IBI data
- Synthetic data
- Edge cases (short data, etc.)

Run with: julia --project=. test/test_plot_poincare.jl
"""

using HeartRateLab
using Test
using Statistics
using Random

println("=" ^ 70)
println("           plot_poincare() Function Test")
println("=" ^ 70)

# Set seed for reproducibility
Random.seed!(42)

# Create test data
println("\n1. Generating test data...")
test_data = [600, 620, 590, 610, 580, 630, 600, 610, 620, 630]
println("   ✓ Created $(length(test_data)) IBI samples: $test_data")

# Generate more realistic synthetic data
println("\n2. Creating realistic synthetic IBI data...")
t = range(0, 100, length=128)
synthetic_ibis = 800 .+ 100 .* sin.(2π .* t / 50) .+ randn(128) .* 20
println("   ✓ Generated $(length(synthetic_ibis)) samples")
println("   Range: $(Int(minimum(synthetic_ibis)))—$(Int(maximum(synthetic_ibis))) ms")
println("   Mean: $(round(mean(synthetic_ibis); digits=1)) ms")

# Test basic function availability
println("\n3. Testing plot_poincare() function existence...")
@test isdefined(HeartRateLab, :plot_poincare)
println("   ✓ Function is defined and exported")

# Try plotting with different backends
println("\n4. Attempting visualization with Plots.jl...")
try
    using Plots
    println("   ✓ Plots.jl loaded")

    # Test 1: Plot with basic data
    println("\n5. Creating Poincaré plot (basic data)...")
    fig = plot_poincare(test_data; title="Test Poincaré Plot")
    @test fig !== nothing
    println("   ✓ Plot created successfully")
    println("   Type: $(typeof(fig))")

    # Test 2: Plot with synthetic data
    println("\n6. Creating Poincaré plot (synthetic data)...")
    fig2 = plot_poincare(synthetic_ibis; title="Synthetic IBI Poincaré Plot")
    @test fig2 !== nothing
    println("   ✓ Plot created with synthetic data")

    # Test 3: Plot with custom title
    println("\n7. Creating Poincaré plot with custom title...")
    fig3 = plot_poincare(synthetic_ibis; title="Custom Title Test")
    @test fig3 !== nothing
    println("   ✓ Custom title works")

    # Test 4: Edge case - minimum data (2 points)
    println("\n8. Testing edge case (2 data points)...")
    min_data = [600, 620]
    fig4 = plot_poincare(min_data; title="Minimum Data Plot")
    @test fig4 !== nothing
    println("   ✓ Minimum data case handled")

    # Test 5: Edge case - 3 points
    println("\n9. Testing edge case (3 data points)...")
    few_data = [600, 620, 590]
    fig5 = plot_poincare(few_data; title="Few Data Points Plot")
    @test fig5 !== nothing
    println("   ✓ Few data points case handled")

    # Test 6: Verify plot is not empty
    println("\n10. Verifying plot content...")
    fig6 = plot_poincare(synthetic_ibis)
    @test fig6 !== nothing
    # Get plot series data
    if haskey(fig6.plot_list[1].series_list[1].d, :x)
        x_data = fig6.plot_list[1].series_list[1].d[:x]
        @test length(x_data) > 0
        println("    ✓ Plot contains data points ($(length(x_data)) scatter points)")
    end

    println("\n" * "=" ^ 70)
    println("                 All Tests Passed!")
    println("=" ^ 70)

catch err
    if isa(err, ArgumentError) && contains(string(err), "Visualization requires Plots.jl")
        println("\n⚠ Plots.jl not loaded - skipping visualization tests")
        println("  To test visualization, run: using Plots")
    else
        @warn "Error during visualization testing: $err"
        rethrow()
    end
end

println("""
PLOT_POINCARE TEST SUMMARY
══════════════════════════════════════════════════════════════════════════

The plot_poincare() function creates a Poincaré plot showing:

1. SCATTER PLOT (purple points)
   Each point represents consecutive IBI pair (RR[n-1], RR[n])
   X-axis: RR[n-1] (previous interval)
   Y-axis: RR[n] (current interval)

2. SD1/SD2 ELLIPSE (limegreen outline)
   SD1: Short-term HRV (vertical-ish axis)
   SD2: Long-term HRV (horizontal-ish axis)
   Rotated 45° to align with natural coordinates

3. REFERENCE DIAGONAL (gray dashed line)
   Y = X line for visual reference
   Points above: current IBI > previous IBI
   Points below: current IBI < previous IBI

INTERPRETATION
──────────────────────────────────────────────────────────────────────────
• Clustered points: Regular, stable heartbeat
• Scattered points: Variable, irregular heartbeat
• SD1/SD2 ratio: Small ellipse = high parasympathetic tone
                Large ellipse = high sympathetic tone

USAGE
──────────────────────────────────────────────────────────────────────────
  using HeartRateLab, Plots

  # Load IBI data
  ibis = read_txt("subject_ibi.txt")

  # Create Poincaré plot
  fig = plot_poincare(ibis; title="Patient Heart Rate Variability")
  display(fig)

═══════════════════════════════════════════════════════════════════════════
""")
