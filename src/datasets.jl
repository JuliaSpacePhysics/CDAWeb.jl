function find_datasets(name)
    path = joinpath(MASTERS_CDF_PATH, name)
    isfile(path) && return CDFDataset(path)

    # Otherwise, find files whose names contain the substring (case-insensitive)
    lcname = lowercase(name)
    files = filter!(f -> endswith(f, ".cdf") && occursin(lcname, f), readdir(MASTERS_CDF_PATH))
    return map(files) do f
        CDFDataset(joinpath(MASTERS_CDF_PATH, f))
    end
end

"""
    get_dataset(id; kw...)

Get the dataset description by `id`.

The value of `id` may be
- CDAS (e.g., `AC_H2_MFI`),
- DOI (e.g., `10.48322/fh85-fj47`),
- SPASE ResourceID (e.g., `spase://NASA/NumericalData/ACE/MAG/L2/PT1H`).

See also [`get_datasets`](@ref).
"""
get_dataset(id; kw...) = only(get_datasets(; id, kw...))

"""
    get_dataset(id, start_time, stop_time; kw...)

Get the dataset by `id` between `start_time` and `stop_time`.

If no dataset is available for the specified time range, the corresponding master dataset is returned.
"""
function get_dataset(id, start_time, stop_time; clip = false, kw...)
    t0 = DateTime(start_time)
    t1 = DateTime(stop_time)
    file_paths = _get_data_files(t0, t1, id; kw...)
    return if !isempty(file_paths)
        ds = cdfopen(file_paths)
        clip ? view(ds, t0 .. t1) : ds
    else
        @warn "No data available for $(id) in range $(t0) to $(t1). Returning master CDF dataset."
        find_master_cdf(id)
    end
end

"""
    get_dataset_info(id)

Get comprehensive metadata about a dataset, including its description and all
available variables.

Returns a `NamedTuple` with fields:
- `dataset`: the dataset description (Id, Label, Notes, Start, End, Instrument, etc.)
- `variables`: descriptions of all variables in the dataset (Name, ShortDescription, LongDescription)

# Examples
```julia
info = get_dataset_info("AC_H2_MFI")
println(info.dataset.Label)
println(length(info.variables), " variables")
for v in info.variables
    println(v.Name, ": ", v.ShortDescription)
end
```

See also [`get_dataset`](@ref), [`get_variables`](@ref).
"""
function get_dataset_info(id)
    dataset = get_dataset(id)
    variables = get_variables(id)
    return (; dataset, variables)
end
