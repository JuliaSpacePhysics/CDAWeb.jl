"""
    find_datasets(name)

Master CDF datasets whose filenames contain `name` (case-insensitive).
"""
find_datasets(name) = [CDFDataset(joinpath(_masters_path(), f)) for f in _master_files(name)]

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
