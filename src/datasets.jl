# The master CDF stands in when the range has no data
function _get_dataset(id, t0, t1; kw...)
    file_paths = _get_data_files(t0, t1, id; kw...)
    return if !isempty(file_paths)
        cdfopen(file_paths, t0, t1)
    else
        @warn "No data available for $(id) in range $(t0) to $(t1). Returning master CDF dataset."
        find_master_cdf(id)
    end
end
