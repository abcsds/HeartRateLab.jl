module Visualization

function getellipsepoints(cx, cy, rx, ry, θ; length=100)
	t = range(0, 2*pi, length=length)
	ellipse_x_r = @. rx * cos(t)
	ellipse_y_r = @. ry * sin(t)
	R = [cos(θ) sin(θ); -sin(θ) cos(θ)]
	r_ellipse = [ellipse_x_r ellipse_y_r] * R
	x = @. cx + r_ellipse[:,1]
	y = @. cy + r_ellipse[:,2]
	(x,y)
end

function default()
    include("default.jl")
end

function bpm()
    include("heart_rate.jl")
end

function bpm_tt()
    include("heart_rate_tt.jl")
end

function geometric()
    include("geometric.jl")
end

end