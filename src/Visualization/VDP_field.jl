## VDP_field.jl — Van der Pol animated phase-portrait + time series + IBI
##
## Four panels (layout mirrors the Python VDP_field.py):
##   [Phase portrait  | Y(t)       ]
##   [X(t)            | IBI (ms)   ]
##
## Peaks of Y(t) (local maxima) are marked with ✕ and the interval
## between consecutive peaks is stored and displayed as an IBI in ms
## (simulation time unit treated as 1 second → × 1000).
##
## Usage:
##   julia --project=. src/Visualization/VDP_field.jl
##   … or from the REPL:
##   include("src/Visualization/VDP_field.jl")

using GLMakie

# ─── 1. Simulation parameters ────────────────────────────────────────────────

const μ  = 1.0          # Van der Pol non-linearity
const DT = 0.1          # Euler step (simulation time units)
const T0 = 0.0
const T1 = 50.0

# ─── 2. Integrate Van der Pol with Euler method ──────────────────────────────

# ẋ = y
# ẏ = μ(1 − x²)(y − 0.1) − x    (same equations as the Python reference)
vdp_rhs(x, y) = (y,  μ * (1 - x^2) * (y - 0.1) - x)

t_sim = collect(range(T0, T1 - DT; step = DT))
N     = length(t_sim)

xs = zeros(N)
ys = zeros(N)
xs[1], ys[1] = 2.0, 0.0

for i in 2:N
    dx, dy = vdp_rhs(xs[i-1], ys[i-1])
    xs[i] = xs[i-1] + DT * dx
    ys[i] = ys[i-1] + DT * dy
end

# ─── 3. Peak detection: maxima of Y (dy: + → ≤ 0) ───────────────────────────

dy_num    = diff(ys)
peak_idx  = [i+1 for i in 1:(length(dy_num)-1)
             if dy_num[i] > 0 && dy_num[i+1] <= 0]

peak_times = t_sim[peak_idx]           # sim-time of each peak
peak_ys    = ys[peak_idx]

# IBIs: time between successive peaks, converted to ms (1 sim-unit ≡ 1 s)
ibi_times  = peak_times[2:end]         # time-stamp of the "arrival" IBI event
ibi_ms     = diff(peak_times) .* 1000  # ms

# ─── 4. Slope-field arrows ───────────────────────────────────────────────────

grid_pts = range(-3, 3; length = 15)
gx = vec([gx for gx in grid_pts, gy in grid_pts])
gy = vec([gy for gx in grid_pts, gy in grid_pts])

raw_u = copy(gy)
raw_v = μ .* (1 .- gx.^2) .* (gy .- 0.1) .- gx
M     = hypot.(raw_u, raw_v)
M[M .== 0] .= 1
gu = raw_u ./ M .* 0.22     # scale arrow length for visual clarity
gv = raw_v ./ M .* 0.22

# ─── 5. Figure & static elements ─────────────────────────────────────────────

fig = Figure(size = (1060, 820))

ax_phase = Axis(fig[1, 1:2],
    title  = "Phase Portrait",
    xlabel = "X  (a.u.)",
    ylabel = "Y  (a.u.)")

ax_yt = Axis(fig[1, 3],
    title  = "Y(t)",
    xlabel = "Time",
    ylabel = "Y")

ax_xt = Axis(fig[2, 1:2],
    title  = "X(t)",
    xlabel = "Time",
    ylabel = "X")

ax_ibi = Axis(fig[2, 3],
    title  = "Inter-Beat Intervals",
    xlabel = "Time",
    ylabel = "IBI  (ms)")

# Axes limits (fixed so the animation doesn't rescale)
xlims!(ax_phase, -3.3, 3.3);  ylims!(ax_phase, -3.3, 3.3)
xlims!(ax_yt,    T0,   T1);   ylims!(ax_yt,    minimum(ys) - 0.4, maximum(ys) + 0.4)
xlims!(ax_xt,    T0,   T1);   ylims!(ax_xt,    minimum(xs) - 0.4, maximum(xs) + 0.4)
xlims!(ax_ibi,   T0,   T1)
if !isempty(ibi_ms)
    ylims!(ax_ibi, minimum(ibi_ms) - 100, maximum(ibi_ms) + 100)
end

# Static slope-field arrows
arrows!(ax_phase, gx, gy, gu, gv;
        color     = (:gray60, 0.6),
        arrowsize = 7,
        linewidth = 1.2)

# ─── 6. Observables ─────────────────────────────────────────────────────────

frame = Observable(1)

# Trajectory and current-position dot in phase space
traj_x  = @lift xs[1:$frame]
traj_y  = @lift ys[1:$frame]
dot_px  = @lift [xs[$frame]]
dot_py  = @lift [ys[$frame]]

# Time axis shared by X(t) and Y(t)
cur_t   = @lift t_sim[1:$frame]
cur_x   = @lift xs[1:$frame]
cur_y   = @lift ys[1:$frame]
dot_t   = @lift [t_sim[$frame]]
dot_xv  = @lift [xs[$frame]]
dot_yv  = @lift [ys[$frame]]

# Peaks visible so far (their index has been reached by the animation)
vis_pidx  = @lift peak_idx[peak_idx .<= $frame]
vis_pt    = @lift t_sim[$vis_pidx]
vis_py    = @lift ys[$vis_pidx]

# IBIs whose *second* peak has been reached
vis_ibi_sel = @lift begin
    mask = findall(i -> peak_idx[i+1] <= $frame, 1:(length(peak_idx)-1))
    mask
end
vis_ibi_t  = @lift isempty($vis_ibi_sel) ? Float64[] : ibi_times[$vis_ibi_sel]
vis_ibi_ms = @lift isempty($vis_ibi_sel) ? Float64[] : ibi_ms[$vis_ibi_sel]

# ─── 7. Dynamic plot elements ────────────────────────────────────────────────

# Phase portrait
lines!(  ax_phase, traj_x, traj_y;   color = :royalblue, linewidth = 1.6)
scatter!(ax_phase, dot_px,  dot_py;  color = :red, markersize = 11)

# Y(t) with peak markers
lines!(  ax_yt, cur_t, cur_y;   color = :royalblue, linewidth = 1.6)
scatter!(ax_yt, dot_t, dot_yv;  color = :red, markersize = 11)
scatter!(ax_yt, vis_pt, vis_py; marker = :xcross, color = :black,
         markersize = 13, strokewidth = 2)

# X(t)
lines!(  ax_xt, cur_t, cur_x;  color = :steelblue, linewidth = 1.6)
scatter!(ax_xt, dot_t, dot_xv; color = :red, markersize = 11)

# IBI panel
lines!(  ax_ibi, vis_ibi_t, vis_ibi_ms; color = :mediumpurple, linewidth = 1.5)
scatter!(ax_ibi, vis_ibi_t, vis_ibi_ms; color = :mediumpurple, markersize = 7)

# ─── 8. Animate & save GIF ───────────────────────────────────────────────────

const GIF_PATH   = get(ENV, "VDP_GIF", "vanderpol.gif")
const FRAME_SKIP = 2     # record every 2nd sim-step → fewer frames, faster export
const FPS        = 20

@info "Recording animation → $GIF_PATH  ($(ceil(Int, N/FRAME_SKIP)) frames @ $(FPS) fps)"

record(fig, GIF_PATH, 1:FRAME_SKIP:N; framerate = FPS) do i
    frame[] = i
end

@info "GIF saved: $GIF_PATH"
