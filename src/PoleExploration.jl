using AbstractPlotting.MakieLayout
using Makie
using ControlSystems
using UnicodeFun

include("roots.jl")
include("plotting.jl")

function run()
    # Variables
    roots = Node(Root[Root(Point2f0(-1, 0), true, false)])

    zeros = lift(get_zeros, roots)
    poles = lift(get_poles, roots)
    selected = lift(get_selected, roots)
    gain = Node{Float32}(1.0)
    
    sys = lift((z, p, k) -> begin
        zpk([a + b*im for (a, b) in z], [a + b*im for (a, b) in p], k)
    end, zeros, poles, gain)

    # Parent scene
    outer_padding = 30
    scene, layout = layoutscene(outer_padding, resolution = (1200, 1000), backgroundcolor = RGBf0(0.98, 0.98, 0.98))
    # update_limits!(scene, )

    # Root locus
    root_ax = layout[1:2, 1] = LAxis(scene, title = "Root locus")
    root_plot = scatter!(root_ax, poles, color=:red, marker='+', markersize=10)

    # Step plot
    step_ax = layout[3, 1] = LAxis(scene, title = "Step")
    step_points = lift(sys -> begin
        y, t, x = step(sys)
        limits!(step_ax, minimum(t), maximum(t), minimum(y), maximum(y))
        convert.(Point2f0, zip(t, vec(y)))
    end, sys)
    lines!(step_ax, step_points)

    # Impulse plot
    impulse_ax = layout[4, 1] = LAxis(scene, title = "Impulse")
    impulse_points = lift(sys -> begin
        y, t, x = impulse(sys)
        convert.(Point2f0, zip(t, vec(y)))
    end, sys)
    lines!(impulse_ax, impulse_points)

    # Bode plot
    bodemag_ax = layout[1, 2] = LAxis(scene, title = "Magnitude")
    bodephase_ax = layout[2, 2] = LAxis(scene, title = "Phase")
    linkxaxes!(bodemag_ax, bodephase_ax)
    bodeout = lift(bode, sys) # TODO use nyquist instead to calculate this?
    bodemag_points = lift(x -> convert.(Point2f0, zip(log.(x[3]), log.(x[1]))), bodeout)
    bodephase_points = lift(x -> convert.(Point2f0, zip(log.(x[3]), x[2])), bodeout)
    lines!(bodemag_ax, bodemag_points)
    lines!(bodephase_ax, bodephase_points)

    # Nyquist plot
    nyquist_ax = layout[3:4, 2] = LAxis(scene, title = "Nyquist")
    nyquist_points = lift(sys -> begin
        a, b, _ = nyquistv(sys)
        convert.(Point2f0, zip(a, b))
    end, sys)
    lines!(nyquist_ax, nyquist_points)

    gain_slider = LSlider(scene, range=0.01:0.01:10, startvalue=gain[])
    gain_label = LText(scene, lift(x -> "K=$(x)", gain_slider.value))
    on(gain_slider.value) do value
        gain[] = value
    end
    layout[0, 1] = hbox!(gain_slider, gain_label)

    # Other
    tf_text = lift(sys -> begin
        io = IOBuffer()
        ControlSystems.print_siso(io, sys.matrix[1, 1])
        String(take!(io))[1:end-1]
    end, sys)
    tf_label = layout[0, 2] = LText(scene, text=tf_text, tellwidth=false)

    mousestate = addmousestate!(root_ax.scene)
    onmouseleftdragstart(mousestate) do state
        find_close(state.pos, poles[], zeros[], [1, 1])
    end
    onmouseleftdrag(mousestate) do state
        println("drag")
    end
    onmouseleftdragstop(mousestate) do state
        println("dragend")
    end
    onmouseleftclick(mousestate) do state
        # Find closest point, if point is within reasonable distance given scale select it
        find_close(state.pos, poles[], zeros[], [1, 1])
    end

    on(scene.events.keyboardbuttons) do button
        if ispressed(button, Keyboard.space)
            poles[] = Point2f0[(-1, 0)]
            zeros[] = Array{Point{2, Float32}, 1}(undef, 0)
        elseif ispressed(button, Keyboard.c)
            poles[] = push!(poles[], Point2f0(-1, 1), Point2f0(-1, -1))
        elseif ispressed(button, Keyboard.r)
            poles[] = push!(poles[], Point2f0(-1, 0))
        elseif ispressed(button, Keyboard.delete)
            
        end
    end

    scene
end

scene = run()