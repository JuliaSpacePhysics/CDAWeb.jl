_format_time(time) = Dates.format(time, "yyyymmddTHHMMSS") * "Z"
_format_time(time::AbstractString) = _format_time(DateTime(time))

# https://github.com/SciQLop/PyISTP/blob/main/pyistp/_impl.py#L16

function _get_data(dataset, var, t0, t1; master_attributes = false, kw...)
    start_time = DateTime(t0)
    stop_time = DateTime(t1)
    file_paths = get_data_files(dataset, var, start_time, stop_time; kw...)

    # Handle case where no data files are available (e.g., 404 error)
    if isempty(file_paths)
        @warn "No data available for $(dataset)/$(var) in range $(start_time) to $(stop_time). Returning empty Variable from master CDF."
        master_cdf = find_master_cdf(dataset)
        return master_cdf[var]
    end
    ds = cdfopen(file_paths, start_time, stop_time)
    metadata = master_attributes ? find_master_cdf(dataset)[var].attrib : nothing
    return variable(ds, var; metadata)
end

function _split_path(path)
    parts = split(path, '/', limit=2)
    length(parts) == 1 && return String(path), nothing
    dataset, variable = String(parts[1]), String(parts[2])
    @assert !isempty(dataset) "dataset name cannot be empty"
    @assert !isempty(variable) "variable name cannot be empty"
    return dataset, variable
end
