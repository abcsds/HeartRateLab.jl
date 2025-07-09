using GLMakie
using LSL
# using TerminalMenus
using Statistics

# Get the available streams
streams = LSL.resolve_streams(timeout=1.0)

while isempty(streams)
    global streams
    println("No streams found. Retrying...")
    streams = LSL.resolve_streams(timeout=1.0);
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
t = Observable(zeros(Float64, sample_size));
t_rr = Observable(zeros(Float64, sample_size));
bpm = Observable(zeros(Float64, sample_size));
avg_bpm = Observable(0.0);
title_rr = Observable("Heart Rate");

# Create the plots
fig = Figure(size=(1920, 1080));
ax_rr = Axis(fig[1, 1:5], title=title_rr, ylabel="Heart Rate (BPM)");
# ax_rr.yreversed = true;

# hidespines!(ax_rm)
# hidedecorations!(ax_rm)

# Plot the initial data
lines!(ax_rr, t, bpm, color=:teal);
hlines!(avg_bpm, color=:coral)


# Display the initial plot
rr[] = fill(sample[1], sample_size);
bpm[] = 6000 ./ rr[]
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
    bpm[][i] = 60000 / sample[1]
    if i == 1
        t[][i] = timestamp
        t_rr[][i] = timestamp
    else
        t_rr[][i] = t[][i-1] + (sample[1] / 1000)
        t[][i] = timestamp
    end
    # fill the rest of the arrays
    rr[][i+1:end] = repeat([rr[][i]], length(rr[])-i)
    bpm[] = 60000 ./ rr[]
    avg_bpm[] = mean(bpm[])
    t[][i+1:end] = repeat([t[][i]], length(t[])-i)
    t_rr[][i+1:end] = repeat([t_rr[][i]], length(t_rr[])-i)

    # Update observables
    rr[] = rr[]
    t[] = t[]
    t_rr[] = t_rr[]
    println("$i at t: $(t[][i]) ($timestamp) : $(sample[1])")
    title_rr[] = "Heart Rate (BPM: $(round(avg_bpm[], digits=1)) AVGBPM: $(round(60000 / mean(rr[]), digits=1)))";
    autolimits!(ax_rr)
    i+=1
end

# lines!(ax_ff, freq, power, color=:teal);

# Update the plot
while true
    global timestamp, sample
    timestamp, sample = pull_sample!(sample, inlet, timeout=1.0)
    if timestamp == 0.0 || sample[1] < 0
        continue
    end
    println("t: $timestamp : $(sample[1])")
    rr[] = [rr[][2:end]; sample[1]];
    bpm[] = 60000 ./ rr[];
    avg_bpm[] = mean(bpm[])
    t_rr[] = [t[][2:end]; t[][end] + (sample[1] / 1000)];
    t[] = [t[][2:end]; timestamp];
   

    title_rr[] = "RR Interval (BPM: $(round(avg_bpm[], digits=1)) AVGBPM: $(round(60000 / mean(rr[]), digits=1)))";
    autolimits!(ax_rr)
end