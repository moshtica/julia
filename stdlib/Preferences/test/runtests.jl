using Base: UUID
using Preferences, Test, TOML, Pkg

function with_temp_project(f::Function)
    mktempdir() do dir
        saved_active_project = Base.ACTIVE_PROJECT[]
        Base.ACTIVE_PROJECT[] = dir
        try
            f(dir)
        finally
            Base.ACTIVE_PROJECT[] = saved_active_project
        end
    end
end

function with_temp_depot_and_project(f::Function)
    mktempdir() do dir
        saved_depot_path = copy(Base.DEPOT_PATH)
        empty!(Base.DEPOT_PATH)
        push!(Base.DEPOT_PATH, dir)
        try
            with_temp_project(f)
        finally
            empty!(Base.DEPOT_PATH)
            append!(Base.DEPOT_PATH, saved_depot_path)
        end
    end
end

# Some useful constants
up_uuid = UUID(TOML.parsefile(joinpath(@__DIR__, "UsesPreferences", "Project.toml"))["uuid"])

@testset "Preferences" begin
    # Create a temporary package, store some preferences within it.
    with_temp_project() do project_dir
        uuid = UUID(UInt128(0))
        save_preferences!(uuid, Dict("foo" => "bar"))

        project_path = joinpath(project_dir, "Project.toml")
        @test isfile(project_path)
        proj = TOML.parsefile(project_path)
        @test haskey(proj, "preferences")
        @test isa(proj["preferences"], Dict)
        @test haskey(proj["preferences"], string(uuid))
        @test isa(proj["preferences"][string(uuid)], Dict)
        @test proj["preferences"][string(uuid)]["foo"] == "bar"

        prefs = modify_preferences!(uuid) do prefs
            prefs["foo"] = "baz"
            prefs["spoon"] = [Dict("qux" => "idk")]
        end
        @test prefs == load_preferences(uuid)

        clear_preferences!(uuid)
        proj = TOML.parsefile(project_path)
        @test !haskey(proj, "preferences")
    end

    # Do a test within a package to ensure that we can use the macros
    with_temp_project() do project_dir
        Pkg.develop(path=joinpath(@__DIR__, "UsesPreferences"))

        # Run UsesPreferences tests manually, so that they can run in the explicitly-given project
        test_script = joinpath(@__DIR__, "UsesPreferences", "test", "runtests.jl")
        run(`$(Base.julia_cmd()) --project=$(project_dir) $(test_script)`)

        # Load the preferences, ensure we see the `jlFPGA` backend:
        prefs = load_preferences(up_uuid)
        @test haskey(prefs, "backend")
        @test prefs["backend"] == "jlFPGA"
    end

    # Run another test, this time setting up a whole new depot so that compilation caching can be checked:
    with_temp_depot_and_project() do project_dir
        Pkg.develop(path=joinpath(@__DIR__, "UsesPreferences"))

        # Helper function to run a sub-julia process and ensure that it either does or does not precompile.
        function did_precompile()
            out = Pipe()
            cmd = setenv(`$(Base.julia_cmd()) -i --project=$(project_dir) -e 'using UsesPreferences; exit(0)'`, "JULIA_DEPOT_PATH" => Base.DEPOT_PATH[1], "JULIA_DEBUG" => "loading")
            run(pipeline(cmd, stdout=out, stderr=out))
            close(out.in)
            output = String(read(out))
            # println(output)
            # prefs = load_preferences(up_uuid)
            # @show prefs, string(hash(prefs), base=16)
            return occursin("Precompiling UsesPreferences [$(string(up_uuid))]", output)
        end

        # Initially, we must precompile, of course, because no preferences are set.
        @test did_precompile()
        # Next, we recompile, because the preferences have been altered
        @test did_precompile()
        # Finally, we no longer have to recompile.
        @test !did_precompile()

        # Modify the preferences, ensure that causes precompilation and then that too shall pass.
        prefs = modify_preferences!(up_uuid) do prefs
            prefs["backend"] = "something new"
        end
        @test did_precompile()
        @test !did_precompile()
    end
end