module Preferences
using TOML
using Base: UUID

export load_preferences, @load_preferences,
       save_preferences!, @save_preferences!,
       modify_preferences!, @modify_preferences!,
       clear_preferences!, @clear_preferences!

# Helper function to get the UUID of a module, throwing an error if it can't.
function get_uuid(m::Module)
    uuid = Base.PkgId(m).uuid
    if uuid === nothing
        throw(ArgumentError("Module does not correspond to a loaded package!"))
    end
    return uuid
end


"""
    load_preferences(uuid_or_module)

Load the preferences for the given package, returning them as a `Dict`.  Most users
should use the `@load_preferences()` macro which auto-determines the calling `Module`.
"""
function load_preferences(uuid::UUID)
    prefs = Dict{String,Any}()

    # Finally, load from the currently-active project:
    proj_path = Base.active_project()
    if isfile(proj_path)
        project = TOML.parsefile(proj_path)
        if haskey(project, "preferences") && isa(project["preferences"], Dict)
            prefs = get(project["preferences"], string(uuid), Dict())
        end
    end
    return prefs
end
load_preferences(m::Module) = load_preferences(get_uuid(m))


"""
    save_preferences!(uuid_or_module, prefs::Dict)

Save the preferences for the given package.  Most users should use the
`@save_preferences!()` macro which auto-determines the calling `Module`.  See also the
`modify_preferences!()` function (and the associated `@modifiy_preferences!()` macro) for
easy load/modify/save workflows.
"""
function save_preferences!(uuid::UUID, prefs::Dict)
    # Save to Project.toml
    proj_path = Base.active_project()
    mkpath(dirname(proj_path))
    project = Dict{String,Any}()
    if isfile(proj_path)
        project = TOML.parsefile(proj_path)
    end
    if !haskey(project, "preferences")
        project["preferences"] = Dict{String,Any}()
    end
    if !isa(project["preferences"], Dict)
        error("$(proj_path) has conflicting `preferences` entry type: Not a Dict!")
    end
    project["preferences"][string(uuid)] = prefs
    open(proj_path, "w") do io
        TOML.print(io, project, sorted=true)
    end
    return nothing
end
function save_preferences!(m::Module, prefs::Dict)
    return save_preferences!(get_uuid(m), prefs)
end


"""
    modify_preferences!(f::Function, uuid::UUID)
    modify_preferences!(f::Function, m::Module)

Supports `do`-block modification of preferences.  Loads the preferences, passes them to a
user function, then writes the modified `Dict` back to the preferences file.  Example:

```julia
modify_preferences!(@__MODULE__) do prefs
    prefs["key"] = "value"
end
```

This function returns the full preferences object.  Most users should use the
`@modify_preferences!()` macro which auto-determines the calling `Module`.
Note that this method does not support modifying depot-wide preferences; modifications
always are saved to the active project.
"""
function modify_preferences!(f::Function, uuid::UUID)
    prefs = load_preferences(uuid)
    f(prefs)
    save_preferences!(uuid, prefs)
    return prefs
end
modify_preferences!(f::Function, m::Module) = modify_preferences!(f, get_uuid(m))


"""
    clear_preferences!(uuid::UUID)
    clear_preferences!(m::Module)

Convenience method to remove all preferences for the given package.  Most users should
use the `@clear_preferences!()` macro, which auto-determines the calling `Module`.
"""
function clear_preferences!(uuid::UUID)
    # Clear the project preferences key, if it exists
    proj_path = Base.active_project()
    if isfile(proj_path)
        project = TOML.parsefile(proj_path)
        if haskey(project, "preferences") && isa(project["preferences"], Dict)
            delete!(project["preferences"], string(uuid))
            open(proj_path, "w") do io
                TOML.print(io, project, sorted=true)
            end
        end
    end
end


"""
    @load_preferences()

Convenience macro to call `load_preferences()` for the current package.
"""
macro load_preferences()
    return quote
        load_preferences($(esc(get_uuid(__module__))))
    end
end


"""
    @save_preferences!(prefs)

Convenience macro to call `save_preferences!()` for the current package.
"""
macro save_preferences!(prefs)
    return quote
        save_preferences!($(esc(get_uuid(__module__))), $(esc(prefs)))
    end
end


"""
    @modify_preferences!(func)

Convenience macro to call `modify_preferences!()` for the current package.
"""
macro modify_preferences!(func)
    return quote
        modify_preferences!($(esc(func)), $(esc(get_uuid(__module__))))
    end
end


"""
    @clear_preferences!()

Convenience macro to call `clear_preferences!()` for the current package.
"""
macro clear_preferences!()
    return quote
        preferences!($(esc(get_uuid(__module__))))
    end
end

end # module Preferences