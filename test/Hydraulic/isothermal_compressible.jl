using ModelingToolkit, OrdinaryDiffEq, Test
using ModelingToolkit: t_nounits as t, D_nounits as D
import ModelingToolkitStandardLibrary.Hydraulic.IsothermalCompressible as IC
import ModelingToolkitStandardLibrary.Blocks as B
import ModelingToolkitStandardLibrary.Mechanical.Translational as T

using ModelingToolkitStandardLibrary.Blocks: Parameter

NEWTON = NLNewton(check_div = false, always_new = true, max_iter = 100, relax = 9 // 10)

@testset "Fluid Domain and Tube" begin
    function System(N; bulk_modulus, name)
        pars = @parameters begin
            bulk_modulus = bulk_modulus
        end

        systems = @named begin
            fluid = IC.HydraulicFluid(; bulk_modulus)
            stp = B.Step(; height = 2*101325, offset = 101325, start_time = 0.05, duration = Inf,
                smooth = false)
            src = IC.Pressure(;)
            vol = IC.FixedVolume(; vol = 10.0)
            res = IC.Tube(N; area = 0.01, length = 50.0)
        end

        eqs = [connect(stp.output, src.p)
               connect(fluid, src.port)
               connect(src.port, res.port_a)
               connect(res.port_b, vol.port)]

               ODESystem(eqs, t, [], pars; name, systems)
    end

    @named sys1_2 = System(1; bulk_modulus = 1e9)
    @named sys1_1 = System(1; bulk_modulus = 1e7)
    @named sys5_1 = System(5; bulk_modulus = 1e9)

#    syss = structural_simplify.([sys1_2, sys1_1, sys5_1])

# system 1_1
    sys1_1 = structural_simplify(sys1_1)
    initialization_eqs = [sys1_1.vol.port.p ~ 101325, sys1_1.res.port_a.dm ~ 0]
    initsys1_1 = ModelingToolkit.generate_initializesystem(sys1_1;initialization_eqs)
    # here the structural_simplify of the initialization system fails, this is an indication that something needs to be fixed with the way the defaults/initial equaitons are defined

    initsys1_1 = structural_simplify(initsys1_1)
    initprob1_1 = NonlinearProblem(initsys1_1, [t=>0])
    initsol1_1 = solve(initprob1_1)
    initsol1_1[sys1_1.src.port.p]
    initsol1_1[sys1_1.src.port.dm]
    initsol1_1[sys1_1.vol.port.p]
#    probs = [ODEProblem(sys, ModelingToolkit.missing_variable_defaults(sys), (0, 0.05))
#             for sys in syss] #
#    prob1_1 = ODEProblem(sys1_1, ModelingToolkit.missing_variable_defaults(sys), (0, 1.05))
    prob1_1 = ODEProblem(sys1_1, [], (0, 50); initialization_eqs)
              #

#    sols = [solve(prob, ImplicitEuler(nlsolve = NEWTON); dt = 1e-4, adaptive = false)
#            for prob in probs]

    sol1_1 = solve(prob1_1, Rodas5P())

#    s1_2 = complete(sys1_2)
    s1_1 = complete(sys1_1)
#    s5_1 = complete(sys5_1)

# system 1_2
    sys1_2 = structural_simplify(sys1_2)
    initialization_eqs = [sys1_2.vol.port.p ~ 101325, sys1_2.res.port_a.dm ~ 0]
    initsys1_2 = ModelingToolkit.generate_initializesystem(sys1_2;initialization_eqs)

    initsys1_2 = structural_simplify(initsys1_2)
    initprob1_2 = NonlinearProblem(initsys1_2, [t=>0])
    initsol1_2 = solve(initprob1_2)

    prob1_2 = ODEProblem(sys1_2, [], (0, 50); initialization_eqs)
    sol1_2 = solve(prob1_2, Rodas5P())
    s1_2 = complete(sys1_2)
# system 5-1

    sys5_1 = structural_simplify(sys5_1)
    initialization_eqs = [sys5_1.vol.port.p ~ 101325,sys5_1.res.p1.port_a.dm ~ 0,
                        sys5_1.res.v2.port.p ~ 101325,sys5_1.res.v2.port.dm ~ 0,
                        sys5_1.res.v3.port.p ~ 101325,sys5_1.res.v3.port.dm ~ 0,
                        sys5_1.res.v4.port.p ~ 101325,sys5_1.res.v4.port.dm ~ 0]
#   initialization_eqs = [sys5_1.vol.port.p ~ 101325,sys5_1.res.p1.port_a.dm ~ 0]
    initsys5_1 = ModelingToolkit.generate_initializesystem(sys5_1;initialization_eqs)

    initsys5_1 = structural_simplify(initsys5_1)
    initprob5_1 = NonlinearProblem(initsys5_1, [t=>0])
    initsol5_1 = solve(initprob5_1)

    prob5_1 = ODEProblem(sys5_1, [], (0, 50); initialization_eqs)
    sol5_1 = solve(prob5_1, Rodas5P()) # This one does not solve without specifying the solver.
    s5_1 = complete(sys5_1)

    # higher stiffness should compress more quickly and give a higher pressure
    @test sol1_2[s1_2.vol.port.p][end] > sol1_1[s1_1.vol.port.p][end]

    # N=5 pipe is compressible, will pressurize more slowly
    @test sol1_1[s1_1.vol.port.p][end] > sol5_1[s5_1.vol.port.p][end]

    # using CairoMakie
    #  fig = Figure()
    #  ax = Axis(fig[1,1])
    #  # hlines!(ax, 10e5)
    # #  lines!(ax, sols[1][s1_2.vol.port.p])
    # # lines!(ax, sols[2][s1_1.vol.port.p])
    # # lines!(ax, sols[3][s5_1.vol.port.p])
    # lines!(ax, sol1_1.t, sol1_1[s1_1.vol.port.p])
    # lines!(ax, sol1_2.t,sol1_2[s1_2.vol.port.p])
    # lines!(ax, sol5_1.t,sol5_1[s5_1.vol.port.p])
    # #lines!(ax, sol1_2[s1_2.vol.rho])
    #  fig

end

@testset "Valve" begin
    function System(; name)
        pars = []

        systems = @named begin
            fluid = IC.HydraulicFluid()
            sink = IC.FixedPressure(; p = 10e5)
            vol = IC.FixedVolume(; vol = 0.1)
            valve = IC.Valve(; Cd = 1e5, minimum_area = 0)
            ramp = B.Ramp(; height = 1, duration = 0.001, offset = 0, start_time = 0.001,
                smooth = true)
        end

        eqs = [connect(fluid, sink.port)
               connect(sink.port, valve.port_a)
               connect(valve.port_b, vol.port)
               connect(valve.area, ramp.output)]

        ODESystem(eqs, t, [], pars; name, systems)
    end

    @named valve_system = System()
    sys = structural_simplify(valve_system)
    initialization_eqs = [sys.vol.port.p ~ 101325]
    initsys = ModelingToolkit.generate_initializesystem(sys;initialization_eqs)
 #   initsys = structural_simplify(initsys)   
 #   initprob = NonlinearProblem(initsys, [t=>0])
 #   initsol = solve(initprob)
    prob = ODEProblem(sys, [], (0, 0.01))
    sol = solve(prob, Rodas5P())
    s = complete(valve_system)
    


    # the volume should discharge to 10bar
    @test sol[s.vol.port.p][end]≈10e5 atol=1e5
end

@testset "DynamicVolume and minimum_volume feature" begin # Need help here
    function System(N; name, area = 0.01, length = 0.1, damping_volume)
        pars = []

        # DynamicVolume values
        systems = @named begin
            fluid = IC.HydraulicFluid(; bulk_modulus = 1e9)
            src1 = IC.Pressure(;)
            src2 = IC.Pressure(;)

            vol1 = IC.DynamicVolume(N; direction = +1,
                area,
                x_max = length * 2,
                x_min = length * 0.1,
                x_damp = damping_volume / area + length * 0.1)
            vol2 = IC.DynamicVolume(N; direction = -1,
                area,
                x_max = length * 2,
                x_min = length * 0.1,
                x_damp = damping_volume / area + length * 0.1)

            mass = T.Mass(; m = 10)

            sin1 = B.Sine(; frequency = 0.5, amplitude = +0.5e5, offset = 10e5)
            sin2 = B.Sine(; frequency = 0.5, amplitude = -0.5e5, offset = 10e5)
        end

        eqs = [connect(fluid, src1.port)
               connect(fluid, src2.port)
               connect(src1.port, vol1.port)
               connect(src2.port, vol2.port)
               connect(vol1.flange, mass.flange, vol2.flange)
               connect(src1.p, sin1.output)
               connect(src2.p, sin2.output)]

        ODESystem(eqs, t, [], pars; name, systems)
    end

    for N in [1, 2]
        for damping_volume in [0.01 , 0.1 , 0.25]
            println(N)
            println(damping_volume)
        end
    end

    @named system = System(1; damping_volume = 0.01)
    s = complete(system) # What does this do?
    sys = structural_simplify(system)
    initialization_eqs = [sys.vol1.v1.x ~ 0,sys.vol1.x ~ 0,sys.vol2.v1.x ~ 0,sys.vol2.x ~ 0, 
    sys.vol1.p1.port_b.dm ~ 0, sys.vol2.p1.port_b.dm ~ 0,
    sys.vol2.p1.port_b.p ~ 101325,sys.vol1.p1.port_b.p ~ 101325, 
    sys.mass.flange.v ~ 0,sys.mass.flange.f ~ 0,sys.vol2.moving_volume.x ~ 0]
    initsys = ModelingToolkit.generate_initializesystem(sys;initialization_eqs)
    initsys = structural_simplify(initsys)
    initprob = NonlinearProblem(initsys, [t=>0])
    initsol = solve(initprob)

    prob = ODEProblem(sys, (0, 5); initialization_eqs)
    sol = solve(prob)

    for N in [1, 2]
        for damping_volume in [0.01 * 0.1 * 0.25]
            @named system = System(N; damping_volume)
            s = complete(system)
            sys = structural_simplify(system)
            prob = ODEProblem(sys, ModelingToolkit.missing_variable_defaults(sys), (0, 5),
                [s.vol1.Cd_reverse => 0.1, s.vol2.Cd_reverse => 0.1];
                jac = true)

            @time sol = solve(prob,
                ImplicitEuler(nlsolve = NLNewton(check_div = false,
                    always_new = true,
                    max_iter = 10,
                    relax = 9 // 10));
                dt = 0.0001, adaptive = false, initializealg = NoInit())

            # begin
            #     fig = Figure()

            #     ax = Axis(fig[1,1], ylabel="position [m]", xlabel="time [s]")
            #     lines!(ax, sol.t, sol[s.vol1.x]; label="vol1")
            #     lines!(ax, sol.t, sol[s.vol2.x]; label="vol2")
            #     Legend(fig[1,2], ax)

            #     ax = Axis(fig[2,1], ylabel="pressure [bar]", xlabel="time [s]")
            #     lines!(ax, sol.t, sol[s.vol1.damper.port_a.p]/1e5; label="vol1")
            #     lines!(ax, sol.t, sol[s.vol2.damper.port_a.p]/1e5; label="vol2")
            #     ylims!(ax, 10-0.5, 10+0.5)

            #     ax = Axis(fig[3,1], ylabel="area", xlabel="time [s]")
            #     lines!(ax, sol.t, sol[s.vol1.damper.area]; label="area 1")
            #     lines!(ax, sol.t, sol[s.vol2.damper.area]; label="area 2")

            #     display(fig)
            # end

            i1 = round(Int, 1 / 1e-4)
            i2 = round(Int, 2 / 1e-4)
            i3 = round(Int, 3 / 1e-4)
            i4 = round(Int, 4 / 1e-4)

            # volume/mass should stop moving at opposite ends
            @test round(sol[s.vol1.x][1]; digits = 2) == 0.1
            @test round(sol[s.vol2.x][1]; digits = 2) == 0.1
            @test round(sol[s.vol1.x][i1]; digits = 2) == +0.19
            @test round(sol[s.vol2.x][i1]; digits = 2) == +0.01
            @test round(sol[s.vol1.x][i2]; digits = 2) == +0.01
            @test round(sol[s.vol2.x][i2]; digits = 2) == +0.19
            @test round(sol[s.vol1.x][i3]; digits = 2) == +0.19
            @test round(sol[s.vol2.x][i3]; digits = 2) == +0.01
            @test round(sol[s.vol1.x][i4]; digits = 2) == +0.01
            @test round(sol[s.vol2.x][i4]; digits = 2) == +0.19
        end
    end
end

@testset "Actuator System" begin  # Need help here
    function System(use_input, f; name)
        pars = @parameters begin
            p_s = 200e5
            p_r = 5e5

            A_1 = 360e-4
            A_2 = 360e-4

            p_1 = 45e5
            p_2 = 45e5

            l_1 = 0.01
            l_2 = 0.05
            m_f = 250
            g = 0

            d = 100e-3

            Cd = 0.01

            m_piston = 880
        end

        vars = @variables begin
            ddx(t) = 0
        end

        systems = @named begin
            src = IC.FixedPressure(; p = p_s)
            valve = IC.SpoolValve2Way(; g, m = m_f, d, Cd)
            piston = IC.Actuator(5;
                total_length = l_1 + l_2,
                area_a = A_1,
                area_b = A_2,
                m = m_piston,
                g = 0,
                minimum_volume_a = A_1 * 1e-3,
                minimum_volume_b = A_2 * 1e-3,
                damping_volume_a = A_1 * 5e-3,
                damping_volume_b = A_2 * 5e-3)
            body = T.Mass(; m = 1500)
            pipe = IC.Tube(5; area = A_2, length = 2.0)
            snk = IC.FixedPressure(; p = p_r)
            pos = T.Position()

            m1 = IC.FlowDivider(; n = 3)
            m2 = IC.FlowDivider(; n = 3)

            fluid = IC.HydraulicFluid()
        end

        if use_input
            @named input = B.SampledData(Float64)
        else
            @named input = B.TimeVaryingFunction(f)
        end

        push!(systems, input)

        eqs = [connect(input.output, pos.s)
               connect(valve.flange, pos.flange)
               connect(valve.port_a, piston.port_a)
               connect(piston.flange, body.flange)
               connect(piston.port_b, m1.port_a)
               connect(m1.port_b, pipe.port_b)
               connect(pipe.port_a, m2.port_b)
               connect(m2.port_a, valve.port_b)
               connect(src.port, valve.port_s)
               connect(snk.port, valve.port_r)
               connect(fluid, src.port, snk.port)
               D(body.v) ~ ddx]

        ODESystem(eqs, t, vars, pars; name, systems)
    end

    @named system = System(true, nothing)

    sys = structural_simplify(system)
    defs = ModelingToolkit.defaults(sys)
    s = complete(system)
    dt = 1e-4
    time = 0:dt:0.1
    x = @. 0.9 * (time > 0.015) * (time - 0.015)^2 - 25 * (time > 0.02) * (time - 0.02)^3
    defs[s.input.buffer] = Parameter(x, dt)
    #prob = ODEProblem(sys, ModelingToolkit.missing_variable_defaults(sys), (0, 0.1);
    #                  tofloat = false)#, jac = true)
    prob = ODEProblem(sys, ModelingToolkit.missing_variable_defaults(sys), (0, 0.1);
        tofloat = false, jac = true)

    # check the fluid domain
    @test Symbol(defs[s.src.port.ρ]) == Symbol(s.fluid.ρ)
    @test Symbol(defs[s.valve.port_s.ρ]) == Symbol(s.fluid.ρ)
    @test Symbol(defs[s.valve.port_a.ρ]) == Symbol(s.fluid.ρ)
    @test Symbol(defs[s.valve.port_b.ρ]) == Symbol(s.fluid.ρ)
    @test Symbol(defs[s.valve.port_r.ρ]) == Symbol(s.fluid.ρ)
    @test Symbol(defs[s.snk.port.ρ]) == Symbol(s.fluid.ρ)

    # defs[s.piston.Cd_reverse] = 0.1

    prob = remake(prob; tspan = (0, time[end]))
    @time sol = solve(prob, ImplicitEuler(nlsolve = NEWTON); adaptive = false, dt,
        initializealg = NoInit())

    @test sol[sys.ddx][1] == 0.0
    @test maximum(sol[sys.ddx]) > 200
    @test sol[s.piston.x][end]≈0.05 atol=0.01
end

@testset "Prevent Negative Pressure" begin
    @component function System(; name)
        pars = @parameters let_gas = 1

        systems = @named begin
            fluid = IC.HydraulicFluid(; let_gas)
            vol = IC.DynamicVolume(5; p_int = 100e5, area = 0.001, x_int = 0.05,
                x_max = 0.1, x_damp = 0.02, x_min = 0.01, direction = +1)
            mass = T.Mass(; m = 100, g = -9.807, s = 0.05)
            cap = IC.Cap(; p_int = 100e5)
        end

        eqs = [connect(fluid, cap.port, vol.port)
               connect(vol.flange, mass.flange)]

        ODESystem(eqs, t, [], pars; name, systems)
    end

    @named system = System()
    s = complete(system)
    sys = structural_simplify(system)
    prob1 = ODEProblem(sys, ModelingToolkit.missing_variable_defaults(sys), (0, 0.05))
    prob2 = ODEProblem(sys, ModelingToolkit.missing_variable_defaults(sys), (0, 0.05),
        [s.let_gas => 0])

    @time sol1 = solve(prob1, ImplicitEuler(nlsolve = NEWTON); adaptive = false, dt = 1e-4)
    @time sol2 = solve(prob2, Rodas4())

    # case 1: no negative pressure will only have gravity pulling mass back down
    # case 2: with negative pressure, added force pulling mass back down
    # - case 1 should push the mass higher
    @test maximum(sol1[s.mass.s]) > maximum(sol2[s.mass.s])

    # case 1 should prevent negative pressure less than -1000
    @test minimum(sol1[s.vol.port.p]) > -1000
    @test minimum(sol2[s.vol.port.p]) < -1000

    # fig = Figure()
    # ax = Axis(fig[1,1])
    # lines!(ax, sol1.t, sol1[s.vol.port.p])
    # lines!(ax, sol2.t, sol2[s.vol.port.p])

    # ax = Axis(fig[1,2])
    # lines!(ax, sol1.t, sol1[s.mass.s])
    # lines!(ax, sol2.t, sol2[s.mass.s])
    # fig
end

@testset "Component Flow Reversals" begin
# Check Component Flow Reversals
    function System(; name)
        pars = []

        systems = @named begin
            fluid = IC.HydraulicFluid()
            source = IC.Pressure()
            sink = IC.FixedPressure(; p = 101325)
            pipe = IC.Tube(1, false; area = 0.1, length =.1, head_factor = 1)
            osc = Sine(; frequency = 0.01, amplitude = 100, offset = 101325)
        end

        eqs = [connect(fluid, pipe.port_a)
            connect(source.port, pipe.port_a)
            connect(pipe.port_b, sink.port)
            connect(osc.output, source.p)]

        ODESystem(eqs, t, [], []; systems)
    end

    @named sys = System()

    syss = structural_simplify.([sys])
    tspan = (0.0, 1000.0)
    prob = ODEProblem(sys, tspan)  # u0 guess can be supplied or not
    @time sol = solve(prob)
    
end

@testset "Tube Discretization" begin
    # Check Tube Discretization
end

@testset "Pressure BC" begin
    # Ensure Pressure Boundary Condition Works
end

@testset "Massflow BC" begin
    # Ensure Massflow Boundary Condition Works
end

@testset "Splitter Flow Test" begin
    # Ensure FlowDivider Splits Flow Properly
    # 1) Set flow into port A, expect reduction in port B

    # 2) Set flow into port B, expect increase in port B
end

#TODO: Test Valve Inversion
