# Preferences

!!! compat "Julia 1.6"
    Julia's `Preferences` API requires at least Julia 1.6.

Preferences support embedding a simple `Dict` of metadata for a package on a per-project basis.  These preferences allow for packages to set simple, persistent pieces of data that the user has selected, that can persist across multiple versions of a package.

## API Overview

`Preferences` are used primarily through the `@load_preferences`, `@save_preferences` and `@modify_preferences` macros.  These macros will auto-detect the UUID of the calling package, throwing an error if the calling module does not belong to a package.  The function forms can be used to load, save or modify preferences belonging to another package.

Example usage:

```julia
using Preferences

function get_preferred_backend()
    prefs = @load_preferences()
    return get(prefs, "backend", "native")
end

function set_backend(new_backend)
    @modify_preferences!() do prefs
        prefs["backend"] = new_backend
    end
end
```

By default, preferences are stored within the `Project.toml` file of the currently-active project, and as such all new projects will start from a blank state, with all preferences being un-set.
Package authors that wish to have a default value set for their preferences should use the `get(prefs, key, default)` pattern as shown in the code example above.

# API Reference

!!! compat "Julia 1.6"
    Julia's `Preferences` API requires at least Julia 1.6.

```@docs
Preferences.load_preferences
Preferences.@load_preferences
Preferences.save_preferences!
Preferences.@save_preferences!
Preferences.modify_preferences!
Preferences.@modify_preferences!
Preferences.clear_preferences!
Preferences.@clear_preferences!
```