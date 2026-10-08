"""
    find_datasets(name)

Master CDF datasets whose filenames contain `name` (case-insensitive).
"""
find_datasets(name) = [CDFDataset(joinpath(_masters_path(), f)) for f in _master_files(name)]

# The master CDF stands in when the range has no data
function _get_dataset(id, start_time, stop_time; kw...)
    t0 = DateTime(start_time)
    t1 = DateTime(stop_time)
    file_paths = _get_data_files(t0, t1, id; kw...)
    return if !isempty(file_paths)
        cdfopen(file_paths, t0, t1)
    else
        @warn "No data available for $(id) in range $(t0) to $(t1). Returning master CDF dataset."
        find_master_cdf(id)
    end
end
