using GLMakie
using LSL
using StatsBase
using HeartRateLab.Frequency: lomb_scargle, get_power
using HeartRateLab.Visualization: getellipsepoints

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
scatter!(ax_nn, nn50, color=:maroon, markersize=10);

# HRV features
lines!(ax_sd, t, sdnn, color=:teal);
lines!(ax_rm, t, rmssd, color=:coral);

# Poincare plot
scatter!(ax_pp, pp_x, pp_y, color=:purple);
lines!(ax_pp, ellipse_x, ellipse_y, color=:limegreen)

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
        rmssd[][i] = std(nn[])
        pp_x[][i-1] = rr[][i-1]
        pp_y[][i-1] = rr[][i]

        empty!(ax_ff)
        ls=lomb_scargle(Float64.(rr[]))
        vlines!(ax_ff, [0.003, 0.04, 0.15, 0.4], color=:black)
        lines!(ax_ff, ls.freq, ls.power, color=:teal)
        f, p  = find_peak(ls)
        scatter!(ax_ff, [f], [p], marker=:cross, color=:coral)

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
    sd1[] = sqrt(var(pp_x[] - pp_y[] / sqrt(2)))
    sd2[] = sqrt(var(pp_x[] + pp_y[] / sqrt(2)))
    cx[] = mean(pp_x[])
    cy[] = mean(pp_y[])
    ex, ey = getellipsepoints(cx[], cy[], sd2[], sd1[], π/4)
    ellipse_x[] = ex
    ellipse_y[] = ey

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
    if nn50[][1] < t[][1]
        idx = findlast(x -> x < t[][1], nn50[][1:end, 1])
        a = nn50[][idx+1:end, :]
    else
        a = nn50[]
    end
    if abs(nn[][end]) > 50
        b = zeros(Float32, 1, 2) + [t[][end] Float32(nn[][end])]
        nn50[] = [a; b]
    else
        if isempty(a)
            nn50[] = zeros(Float32, 1, 2) + [t[][end] Float32(nn[][end])]
        else
            nn50[] = a
        end
    end
    pnn50[] = 100 * (length(nn50[]) / length(nn[]));
    sdnn[] = [sdnn[][2:end]; std(rr[])];
    rmssd[] = [rmssd[][2:end]; std(nn[])];
    pp_x[] = [pp_x[][2:end]; rr[][end-1]];
    pp_y[] = [pp_y[][2:end]; rr[][end]];
    sd1[] = sqrt(var(pp_x[] - pp_y[] / sqrt(2)))
    sd2[] = sqrt(var(pp_x[] + pp_y[] / sqrt(2)))
    cx[] = mean(pp_x[])
    cy[] = mean(pp_y[])
    ellipse_x[], ellipse_y[] = getellipsepoints(cx[], cy[], sd2[], sd1[], π/4)


    empty!(ax_ff)
    ls=lomb_scargle(Float64.(rr[]))
    lines!(ax_ff, ls.freq, ls.power, color=:teal)
    vlines!(ax_ff, [0.003, 0.04, 0.15, 0.4], color=:black)

    f, p  = find_peak(ls)
    scatter!(ax_ff, [f], [p], marker=:cross, color=:coral)
    vlf=get_power(ls,0.003,0.04)
    lf=get_power(ls,0.04,0.15)
    hf=get_power(ls,0.15,0.4)
    lfhf_ratio=lf/hf
    tp=vlf+lf+hf

    title_rr[] = "RR Interval (BPM: $(round(bpm[], digits=1)) AVGBPM: $(round(60000 / mean(rr[]), digits=1)))";
    title_nn[] = "NN Interval (PNN50: $(round(pnn50[], digits=2))%)";
    title_st[] = "HRV measures (SDNN: $(round(sdnn[][end], digits=1)), RMSSD: $(round(rmssd[][end], digits=1)))";
    title_ff[] = "PS (Peak: $(round(f, digits=2)) Hz, $(round(f*60, digits=2)) BPM),TP: $(round(tp, digits=1)), LF: $(round(lf, digits=1)), HF: $(round(hf, digits=1)), LF/HF: $(round(lfhf_ratio, digits=1)))";
    title_pp[] = "ΔRR[n] vs ΔRR[n-1] (SD1:$(round(sd1[], digits=2)), SD2:$(round(sd2[], digits=2)), SD2/SD1:$(round(sd2[]/sd1[], digits=2)) )"
    autolimits!(ax_rr)
    autolimits!(ax_nn)
    autolimits!(ax_pp)
    autolimits!(ax_sd)
    autolimits!(ax_rm)
    # autolimits!(ax_ff)
end