module Visualization

using GLMakie
using LSL
# using TerminalMenus
using StatsBase


function simple_viz()
    # Get the available streams
    streams = LSL.resolve_streams(timeout=1.0)

    timeout = 5.0; # seconds
    time_now = time()
    while isempty(streams)
        println("No streams found. Retrying...")
        streams = LSL.resolve_streams(timeout=1.0);
        time() - time_now < timeout || error("No streams found after $timeout seconds.")
    end

    # Select the desired stream
    stream_names = [source_id(s) for s in streams]
    selected = findfirst(x -> occursin(r"RR", x), stream_names);
    # menu = RadioMenu([source_id(s) for s in streams], pagesize=10);
    # selected = request(menu);
    stream = streams[selected];

    # Create the inlet
    inlet = StreamInlet(stream);
    open_stream(inlet);
    sleep(0.1)


    # Get the first sample
    timestamp, sample = pull_sample(inlet, timeout=1.0);

    # Create the Observables
    sample_size = 150;
    rr = Observable(zeros(Int32, sample_size));
    sdnn = Observable(zeros(Float64, sample_size));
    nn = Observable(zeros(Int32, sample_size));
    rmssd = Observable(zeros(Float64, sample_size));
    nn50 = Observable(Matrix{Float32}(undef, 0, 2));
    t = Observable(zeros(Float64, sample_size));
    t_rr = Observable(zeros(Float64, sample_size));
    pp_x = Observable(zeros(Int32, sample_size-1));
    pp_y = Observable(zeros(Int32, sample_size-1));
    title_rr = Observable("RR Interval");
    title_nn = Observable("NN Interval");
    title_pp = Observable("ΔRR[n] vs ΔRR[n-1]");
    title_st = Observable("HRV measures");

    # Create the plots
    fig = Figure();
    ax_rr = Axis(fig[1, 1:5], title=title_rr, xlabel="Time (s)", ylabel="RR Interval (ms)");
    ax_rr.yreversed = true;
    ax_nn = Axis(fig[2, 1:5], title=title_nn, xlabel="Time (s)", ylabel="NN Interval (ms)");
    ax_nn.yreversed = true;
    ax_pp = Axis(fig[1:2, 6:10], title=title_pp, xlabel="ΔRR[n-1] (ms)", ylabel="ΔRR[n] (ms)");
    ax_sd = Axis(fig[3:4, 1:5], title=title_st, xlabel="Time (s)", ylabel="SDNN (ms)", yticklabelcolor=:blue);
    ax_rm = Axis(fig[3:4, 1:5], ylabel="RMSSD (ms)", yticklabelcolor=:red, yaxisposition=:right);
    # hidespines!(ax_rm)
    # hidedecorations!(ax_rm)

    # Plot the initial data
    lines!(ax_rr, t, rr, color=:blue);
    lines!(ax_nn, t, nn, color=:red);
    lines!(ax_sd, t, sdnn, color=:blue);
    lines!(ax_rm, t, rmssd, color=:red);
    scatter!(ax_nn, nn50, color=:red, markersize=10);
    scatter!(ax_pp, pp_x, pp_y, color=:green);
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
        if i > sample_size
            break
        end
        timestamp, sample = pull_sample(inlet, timeout=1.0);
        if timestamp == 0.0 || sample[1] < 0
            continue
        end
        rr[][i] = sample[1]
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
            if abs(nn[][i]) > 50
                a = nn50[]
                b = zeros(Float32, 1, 2) + [t[][i] Float32(nn[][i])]
                nn50[] = [a; b]
            end
            sdnn[][i] = std(rr[])
            rmssd[][i] = std(nn[])
            pp_x[][i-1] = rr[][i-1]
            pp_y[][i-1] = rr[][i]
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
        sdnn[] = sdnn[]
        rmssd[] = rmssd[]
        nn50[] = nn50[]
        t[] = t[]
        t_rr[] = t_rr[]
        pp_x[] = pp_x[]
        pp_y[] = pp_y[]
        println("$i at t: $(t[][i]) ($timestamp) : $(sample[1])")
        autolimits!(ax_rr)
        autolimits!(ax_nn)
        autolimits!(ax_pp)
        autolimits!(ax_sd)
        autolimits!(ax_rm)
        i+=1
    end

    # Update the plot
    while true
        timestamp, sample = pull_sample!(sample, inlet, timeout=1.0)
        if timestamp == 0.0 || sample[1] < 0
            continue
        end
        println("t: $timestamp : $(sample[1])")
        rr[] = [rr[][2:end]; sample[1]];
        t_rr[] = [t[][2:end]; t[][end] + (sample[1] / 1000)];
        t[] = [t[][2:end]; timestamp];
        nn[] = [nn[][2:end]; sample[1] - rr[][end-1]];
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
        sdnn[] = [sdnn[][2:end]; std(rr[])];
        rmssd[] = [rmssd[][2:end]; std(nn[])];
        pp_x[] = [pp_x[][2:end]; rr[][end-1]];
        pp_y[] = [pp_y[][2:end]; rr[][end]];
        autolimits!(ax_rr)
        autolimits!(ax_nn)
        autolimits!(ax_pp)
        autolimits!(ax_sd)
        autolimits!(ax_rm)
    end
end
    
end