using GLMakie
using LSL
using StatsBase
using HeartRateLab.Frequency: lomb_scargle, get_power
using HeartRateLab.Visualization: getellipsepoints
using HeartRateLab.Visualization: load_personal_baseline, baseline_band,
    baseline_quantile, baseline_ellipse, baseline_percentile_of, baseline_z,
    _win_rmssd, _win_sd1, _win_sd2

# Percentiles + artifact path come from Visualization.default_normative(...).
bl_low  = HeartRateLab.Visualization._NORMATIVE_LOW[]
bl_high = HeartRateLab.Visualization._NORMATIVE_HIGH[]
bl      = load_personal_baseline(HeartRateLab.Visualization._NORMATIVE_BASELINE_PATH[])

# Time-series bands (RR panel uses per-window MEAN RR — spec §9.2).
meanrr_band = baseline_band(bl, "meanrr"; low = bl_low, high = bl_high)
drr_band    = baseline_band(bl, "drr";    low = bl_low, high = bl_high)
sdnn_band   = baseline_band(bl, "sdnn";   low = bl_low, high = bl_high)
rmssd_band  = baseline_band(bl, "rmssd";  low = bl_low, high = bl_high)
lf_peak_b   = baseline_quantile(bl, "lf_peak", 50)
hf_peak_b   = baseline_quantile(bl, "hf_peak", 50)

# Marginal SD1/SD2 semi-axes at median / low / high — used to (re)build the
# Poincaré envelope ellipses, re-centred on the LIVE cloud each frame (spec §9.3).
bl_sd1_med = baseline_quantile(bl, "sd1", 50);     bl_sd2_med = baseline_quantile(bl, "sd2", 50)
bl_sd1_lo  = baseline_quantile(bl, "sd1", bl_low); bl_sd2_lo  = baseline_quantile(bl, "sd2", bl_low)
bl_sd1_hi  = baseline_quantile(bl, "sd1", bl_high);bl_sd2_hi  = baseline_quantile(bl, "sd2", bl_high)

# Compact "· p73 z+0.6" readout for a panel title.
function _pz(bl, key, value)
    p = baseline_percentile_of(bl, key, value)
    isnan(p) && return ""
    z = baseline_z(bl, key, value)
    return " · p$(round(Int, p)) z$(z >= 0 ? "+" : "")$(round(z; digits = 1))"
end

# Get the available streams
streams = LSL.resolve_streams(timeout=1.0)

while isempty(streams)
    global streams
    println("No streams found. Retrying...")
    streams = LSL.resolve_streams(timeout=1.0);
end


# function getellipsepoints(cx, cy, rx, ry, θ; length=100)
# 	t = range(0, 2*pi, length=length)
# 	ellipse_x_r = @. rx * cos(t)
# 	ellipse_y_r = @. ry * sin(t)
# 	R = [cos(θ) sin(θ); -sin(θ) cos(θ)]
# 	r_ellipse = [ellipse_x_r ellipse_y_r] * R
# 	x = @. cx + r_ellipse[:,1]
# 	y = @. cy + r_ellipse[:,2]
# 	(x,y)
# end

function find_peak(pgram)
    freq = pgram.freq
    power = pgram.power
    return freq[argmax(power)], power[argmax(power)]
end

# Select the desired stream
stream_names = [source_id(s) for s in streams]
selected = findfirst(x -> occursin(r"RR", x), stream_names);
# menu = RadioMenu([source_id(s) for s in streams], pagesize=10);
# selected = request(menu);
stream = streams[selected];
println("Selected stream: $(source_id(stream))");

# Create the inlet
inlet = StreamInlet(stream);
open_stream(inlet);
sleep(0.1)

# Get the first sample
timestamp, sample = pull_sample(inlet, timeout=1.0);

# Create the Observables
sample_size = 100;
rr = Observable(zeros(Int32, sample_size));
sdnn = Observable(zeros(Float64, sample_size));
nn = Observable(zeros(Int32, sample_size));
nn_positive = Observable(zeros(Int32, sample_size));
nn_negative = Observable(zeros(Int32, sample_size));
rmssd = Observable(zeros(Float64, sample_size));
nn50 = Observable(Matrix{Float32}(undef, 0, 2));
t = Observable(zeros(Float64, sample_size));
t_rr = Observable(zeros(Float64, sample_size));
pp_x = Observable(zeros(Int32, sample_size-1));
pp_y = Observable(zeros(Int32, sample_size-1));
sd1 = Observable(0.0)
sd2 = Observable(0.0)
cx = Observable(0.0)
cy = Observable(0.0)
ellipse_x = Observable(zeros(Float64, 100))
ellipse_y = Observable(zeros(Float64, 100))

freq = Observable(Float64[]);
power = Observable(Float64[]);
peak_freq = Observable(0.0)
peak_powr = Observable(0.0)

bpm = Observable(0.0);
pnn50 = Observable(0.0);
title_rr = Observable("RR Interval");
title_nn = Observable("NN Interval");
title_st = Observable("HRV measures");
title_pp = Observable("ΔRR[n] vs ΔRR[n-1]");
title_ff = Observable("Power Spectrum");

# Create the plots
fig = Figure(size=(1920, 1080));
ax_rr = Axis(fig[1, 1:5], title=title_rr, ylabel="RR (ms)");
ax_rr.yreversed = true;
ax_nn = Axis(fig[2, 1:5], title=title_nn, ylabel="NN (ms)");
ax_nn.yreversed = true;
ax_sd = Axis(fig[3:4, 1:5], title=title_st, xlabel="Time (s)", ylabel="SDNN (ms)", yticklabelcolor=:teal);
ax_rm = Axis(fig[3:4, 1:5], ylabel="RMSSD (ms)", yticklabelcolor=:coral, yaxisposition=:right);
ax_pp = Axis(fig[1:2, 6:10], title=title_pp, xlabel="ΔRR[n-1] (ms)", ylabel="ΔRR[n] (ms)");
ax_ff = Axis(fig[3:4, 6:10], title=title_ff, xlabel="Frequency (Hz)", ylabel="Power (ms²/Hz)");
# hidespines!(ax_rm)
# hidedecorations!(ax_rm)

# Plot the initial data
lines!(ax_rr, t, rr, color=:teal);

# Numeric Derivative
hlines!(ax_nn, 0, color=:black);
lines!(ax_nn, t, nn, color=:red);
band!(ax_nn, t, 0, nn_negative, color=:deeppink);
band!(ax_nn, t, 0, nn_positive, color=:blueviolet);
# NN50 markers as an explicit Vector{Point2f} (time, Δnn), filtered to the current window.
# ROOT-CAUSE FIX (d-26): the old `scatter!(ax_nn, nn50)` passed a raw N×2 MATRIX, which Makie
# mis-converts — the Δnn values (column 2) leak into the x-coordinates, producing a negative x
# (≈ the Δnn of an NN50 event) that stretched the shared x-axis to ~0 and squashed the live
# signal whenever an NN50 event was in the window. Building Point2f points fixes the x-range;
# the window filter additionally drops markers that have scrolled off the left.
nn50_visible = lift(nn50, t) do m, tt
    (m === nothing || size(m, 1) == 0) && return Point2f[]
    [Point2f(m[i, 1], m[i, 2]) for i in axes(m, 1) if (m[i, 1] > 0 && m[i, 1] >= tt[1])]
end
scatter!(ax_nn, nn50_visible, color=:maroon, markersize=10);

# HRV features
lines!(ax_sd, t, sdnn, color=:teal);
lines!(ax_rm, t, rmssd, color=:coral);

# Poincare plot — age-faded points + comet trajectory (newest beat opaque, older
# beats fade out), with the SD1/SD2 ellipse. The alpha gradient is positional (index 1
# = oldest in the sliding window, end = newest), so it tracks recency as the window slides.
pp_colors = [RGBAf(0.5, 0.0, 0.5, a) for a in range(0.08, 1.0, length=sample_size - 1)]
lines!(ax_pp, pp_x, pp_y, color=pp_colors, linewidth=1.5);   # comet trail
scatter!(ax_pp, pp_x, pp_y, color=pp_colors, markersize=8);  # age-faded points
lines!(ax_pp, ellipse_x, ellipse_y, color=:limegreen, linewidth=2)

# Frequency
scatter!(ax_ff, [peak_freq[]], [peak_powr[]], marker=:cross, color=:coral)

linkxaxes!(ax_rr, ax_nn);
linkxaxes!(ax_rr, ax_sd);
linkxaxes!(ax_rr, ax_rm)
linkyaxes!(ax_sd, ax_rm);

# Display the initial plot
rr[] = fill(sample[1], sample_size);
t[] = fill(timestamp, sample_size);
t_rr[] = fill(timestamp, sample_size);

# ── Personal-baseline overlays (drawn once, behind the live traces) ──
bandlbl = "personal p$(round(Int,bl_low))–p$(round(Int,bl_high))"

# Shaded band (faded series colour = same entity) + dashed median.
hspan!(ax_rr, meanrr_band.lo, meanrr_band.hi; color = (:teal, 0.12), label = bandlbl)
hlines!(ax_rr, [meanrr_band.med]; color = :teal, linestyle = :dash, linewidth = 1,
        label = "baseline median (mean RR)")

# ΔRR: band EDGES only — no median line (ΔRR median ≈ 0; panel already busy — §9.6).
hlines!(ax_nn, [drr_band.lo, drr_band.hi]; color = (:red, 0.5),
        linestyle = :dash, linewidth = 1, label = bandlbl)

hspan!(ax_sd, sdnn_band.lo, sdnn_band.hi; color = (:teal, 0.12))
hlines!(ax_sd, [sdnn_band.med]; color = :teal, linestyle = :dash, linewidth = 1)

hspan!(ax_rm, rmssd_band.lo, rmssd_band.hi; color = (:coral, 0.12))
hlines!(ax_rm, [rmssd_band.med]; color = :coral, linestyle = :dash, linewidth = 1)

# Poincaré "normal envelope" — marginal SD1/SD2, NOT a density contour (§9.3).
# Observables so the loop can re-centre the ellipses on the live cloud (cx,cy)
# each frame; initialised at the current (0,0) centre.
bl_med_x = Observable(zeros(100)); bl_med_y = Observable(zeros(100))
bl_lo_x  = Observable(zeros(100)); bl_lo_y  = Observable(zeros(100))
bl_hi_x  = Observable(zeros(100)); bl_hi_y  = Observable(zeros(100))
update_bl_ellipses!() = begin
    bl_med_x[], bl_med_y[] = getellipsepoints(cx[], cy[], bl_sd2_med, bl_sd1_med, π/4)
    bl_lo_x[],  bl_lo_y[]  = getellipsepoints(cx[], cy[], bl_sd2_lo,  bl_sd1_lo,  π/4)
    bl_hi_x[],  bl_hi_y[]  = getellipsepoints(cx[], cy[], bl_sd2_hi,  bl_sd1_hi,  π/4)
end
update_bl_ellipses!()
# Recolour the baseline median (live ellipse is limegreen — §9.7 F1): use a
# distinct, colourblind-safe, non-red/green ink.
lines!(ax_pp, bl_med_x, bl_med_y; color = (:navy, 0.9), linewidth = 1.5,
       label = "baseline median (SD1/SD2)")
lines!(ax_pp, bl_lo_x, bl_lo_y; color = (:gray, 0.7), linestyle = :dash, linewidth = 1,
       label = "marginal $(bandlbl)")
lines!(ax_pp, bl_hi_x, bl_hi_y; color = (:gray, 0.7), linestyle = :dash, linewidth = 1)

# Identify the overlays (dataviz: identity never colour-alone). One legend on the
# Poincaré (the most ambiguous panel) + a figure caption naming the reference.
axislegend(ax_pp; position = :rt, framevisible = false, labelsize = 9)
Label(fig[0, :], "Live HRV vs personal baseline (100-beat windows) — " *
      "NOT the population z-score reference"; fontsize = 12, tellwidth = false)

display(fig)

# Fill in the rest of the arrays
i = 1
while true
    global i
    if i > sample_size
        break
    end
    timestamp, sample = pull_sample(inlet, timeout=1.0);
    if timestamp == 0.0 || sample[1] < 0
        continue
    end
    rr[][i] = sample[1]
    bpm[] = 60000 / sample[1]
    if i == 1
        t[][i] = timestamp
        t_rr[][i] = timestamp
        nn[][i] = 0.0
        sdnn[][i] = 0.0
        rmssd[][i] = 0.0
    else
        t_rr[][i] = t[][i-1] + (sample[1] / 1000)
        t[][i] = timestamp
        nn[][i] = sample[1] - rr[][i-1]
        nn_negative[][i] = nn[][i] < 0 ? nn[][i] : 0
        nn_positive[][i] = nn[][i] > 0 ? nn[][i] : 0
        if abs(nn[][i]) > 50
            a = nn50[]
            b = zeros(Float32, 1, 2) + [t[][i] Float32(nn[][i])]
            nn50[] = [a; b]
        end
        sdnn[][i] = std(rr[])
        rmssd[][i] = _win_rmssd(rr[])
        pp_x[][i-1] = rr[][i-1]
        pp_y[][i-1] = rr[][i]

        empty!(ax_ff)
        ls=lomb_scargle(Float64.(rr[]))
        # HRV frequency bands as colour-shaded regions (drawn first, behind the spectrum)
        vspan!(ax_ff, 0.0, 0.0033; color=(:gray, 0.15))        # ULF
        vspan!(ax_ff, 0.0033, 0.04; color=(:blueviolet, 0.16)) # VLF
        vspan!(ax_ff, 0.04, 0.15; color=(:teal, 0.18))         # LF
        vspan!(ax_ff, 0.15, 0.4; color=(:coral, 0.20))         # HF
        lines!(ax_ff, ls.freq, ls.power, color=:black)
        maxp = maximum(ls.power)
        isnan(lf_peak_b) || lines!(ax_ff, [lf_peak_b, lf_peak_b], [0.0, maxp];
                                   color = :black, linestyle = :dash, linewidth = 1)
        isnan(hf_peak_b) || lines!(ax_ff, [hf_peak_b, hf_peak_b], [0.0, maxp];
                                   color = :black, linestyle = :dash, linewidth = 1)
        f, p  = find_peak(ls)
        scatter!(ax_ff, [f], [p], marker=:cross, color=:red)

    end
    # fill the rest of the arrays
    rr[][i+1:end] = repeat([rr[][i]], length(rr[])-i)
    nn[][i+1:end] = repeat([nn[][i]], length(nn[])-i)
    sdnn[][i+1:end] = repeat([sdnn[][i]], length(sdnn[])-i)
    rmssd[][i+1:end] = repeat([rmssd[][i]], length(rmssd[])-i)
    t[][i+1:end] = repeat([t[][i]], length(t[])-i)
    t_rr[][i+1:end] = repeat([t_rr[][i]], length(t_rr[])-i)
    pp_x[][i:end] = repeat([round(mean(pp_x[]), digits=0)], length(pp_x[])-i+1)
    pp_y[][i:end] = repeat([round(mean(pp_y[]), digits=0)], length(pp_y[])-i+1)

    # Update observables
    rr[] = rr[]
    nn[] = nn[]
    nn_negative[] = nn_negative[]
    nn_positive[] = nn_positive[]
    sdnn[] = sdnn[]
    rmssd[] = rmssd[]
    nn50[] = nn50[]
    t[] = t[]
    t_rr[] = t_rr[]
    pp_x[] = pp_x[]
    pp_y[] = pp_y[]
    sd1[] = _win_sd1(rr[])
    sd2[] = _win_sd2(rr[])
    cx[] = mean(pp_x[])
    cy[] = mean(pp_y[])
    ex, ey = getellipsepoints(cx[], cy[], sd2[], sd1[], π/4)
    ellipse_x[] = ex
    ellipse_y[] = ey
    update_bl_ellipses!()   # re-centre the p{low}/median/p{high} envelope on (cx,cy)

    println("$i at t: $(t[][i]) ($timestamp) : $(sample[1])")
    title_rr[] = "RR Interval (BPM: $(round(bpm[], digits=1)) AVGBPM: $(round(60000 / mean(rr[]), digits=1)))";
    title_st[] = "HRV measures (SDNN: $(round(sdnn[][end], digits=1)), RMSSD: $(round(rmssd[][end], digits=1)))";
    autolimits!(ax_rr)
    autolimits!(ax_nn)
    autolimits!(ax_pp)
    autolimits!(ax_sd)
    autolimits!(ax_rm)
    i+=1
end

# lines!(ax_ff, freq, power, color=:teal);
# 

# Update the plot
while true
    global timestamp, sample
    timestamp, sample = pull_sample!(sample, inlet, timeout=1.0)
    if timestamp == 0.0 || sample[1] < 0
        continue
    end
    println("t: $timestamp : $(sample[1])")
    rr[] = [rr[][2:end]; sample[1]];
    bpm[] = 60000 / sample[1];
    t_rr[] = [t[][2:end]; t[][end] + (sample[1] / 1000)];
    t[] = [t[][2:end]; timestamp];
    nn[] = [nn[][2:end]; sample[1] - rr[][end-1]];
    nn_negative[] = [nn_negative[][2:end]; nn[][end] < 0 ? nn[][end] : 0];
    nn_positive[] = [nn_positive[][2:end]; nn[][end] > 0 ? nn[][end] : 0];
    if !isempty(nn50[]) && nn50[][1, 1] < t[][1]
        idx = findlast(x -> x < t[][1], nn50[][1:end, 1])
        a = idx === nothing ? nn50[] : nn50[][idx+1:end, :]
    else
        a = nn50[]
    end
    if abs(nn[][end]) > 50
        b = zeros(Float32, 1, 2) + [t[][end] Float32(nn[][end])]
        nn50[] = [a; b]
    else
        # Sub-threshold beat: NOT an NN50 event — keep the trimmed set, don't fabricate
        # a marker (the old `else` branch created a spurious marker here).
        nn50[] = a
    end
    # NN50 count = number of marker ROWS (length(matrix) counts all elements = 2×rows).
    pnn50[] = 100 * (size(nn50[], 1) / length(nn[]));
    sdnn[] = [sdnn[][2:end]; std(rr[])];
    rmssd[] = [rmssd[][2:end]; _win_rmssd(rr[])];
    pp_x[] = [pp_x[][2:end]; rr[][end-1]];
    pp_y[] = [pp_y[][2:end]; rr[][end]];
    sd1[] = _win_sd1(rr[])
    sd2[] = _win_sd2(rr[])
    cx[] = mean(pp_x[])
    cy[] = mean(pp_y[])
    ellipse_x[], ellipse_y[] = getellipsepoints(cx[], cy[], sd2[], sd1[], π/4)
    update_bl_ellipses!()   # re-centre the p{low}/median/p{high} envelope on (cx,cy)


    empty!(ax_ff)
    ls=lomb_scargle(Float64.(rr[]))
    # HRV frequency bands as colour-shaded regions (drawn first, behind the spectrum)
    vspan!(ax_ff, 0.0, 0.0033; color=(:gray, 0.15))        # ULF
    vspan!(ax_ff, 0.0033, 0.04; color=(:blueviolet, 0.16)) # VLF
    vspan!(ax_ff, 0.04, 0.15; color=(:teal, 0.18))         # LF
    vspan!(ax_ff, 0.15, 0.4; color=(:coral, 0.20))         # HF
    lines!(ax_ff, ls.freq, ls.power, color=:black)
    maxp = maximum(ls.power)
    isnan(lf_peak_b) || lines!(ax_ff, [lf_peak_b, lf_peak_b], [0.0, maxp];
                               color = :black, linestyle = :dash, linewidth = 1)
    isnan(hf_peak_b) || lines!(ax_ff, [hf_peak_b, hf_peak_b], [0.0, maxp];
                               color = :black, linestyle = :dash, linewidth = 1)

    f, p  = find_peak(ls)
    scatter!(ax_ff, [f], [p], marker=:cross, color=:red)
    vlf=get_power(ls,0.003,0.04)
    lf=get_power(ls,0.04,0.15)
    hf=get_power(ls,0.15,0.4)
    lfhf_ratio=lf/hf
    tp=vlf+lf+hf

    title_rr[] = "RR Interval (BPM: $(round(bpm[], digits=1)) AVGBPM: $(round(60000 / mean(rr[]), digits=1)))$(_pz(bl, "meanrr", mean(rr[])))";
    title_nn[] = "NN Interval (PNN50: $(round(pnn50[], digits=2))%)";
    title_st[] = "HRV (SDNN: $(round(sdnn[][end], digits=1))$(_pz(bl, "sdnn", sdnn[][end])), RMSSD: $(round(rmssd[][end], digits=1))$(_pz(bl, "rmssd", rmssd[][end])))";
    title_ff[] = "PS (Peak: $(round(f, digits=2)) Hz, LF: $(round(lf, digits=1)), HF: $(round(hf, digits=1)), LF/HF: $(round(lfhf_ratio, digits=1)); LFpk$(_pz(bl, "lf_peak", f)))";
    title_pp[] = "ΔRR (SD1:$(round(sd1[], digits=2))$(_pz(bl, "sd1", sd1[])), SD2:$(round(sd2[], digits=2))$(_pz(bl, "sd2", sd2[])))"
    autolimits!(ax_rr)
    autolimits!(ax_nn)
    autolimits!(ax_pp)
    autolimits!(ax_sd)
    autolimits!(ax_rm)
    # Defence-in-depth: pin the shared time axis to the live window so no stray geometry can
    # ever stretch it (ax_rr is x-linked to ax_nn/ax_sd/ax_rm). y stays auto from above.
    xlims!(ax_rr, t[][1], t[][end])
    # autolimits!(ax_ff)
end