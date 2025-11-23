_format_time(time) = Dates.format(time, "yyyymmddTHHMMSS") * "Z"
_format_time(time::AbstractString) = _format_time(DateTime(time))

function _build_request_url(dataset, variable, start_time, stop_time; format = "cdf")
    start_str = _format_time(start_time)
    stop_str = _format_time(stop_time)
    return "$(SP_ENDPOINT)/$(dataset)/data/$(start_str),$(stop_str)/$(variable)?format=$(format)"
end

function _build_request_url(dataset, start_time, stop_time)
    start_str = _format_time(start_time)
    stop_str = _format_time(stop_time)
    return "$(SP_ENDPOINT)/$(dataset)/orig_data/$(start_str),$(stop_str)/"
end


function _get_variable_from_file(file_path::String, variable::String)
    dataset = CDFDataset(file_path)
    return try
        dataset[variable]
    catch
        available_vars = collect(keys(dataset))
        throw("Variable '$(variable)' not found in file. Available variables: $(available_vars)")
    end
end

# https://github.com/SciQLop/PyISTP/blob/main/pyistp/_impl.py#L16

"""
    get_data(dataset, [variable,] t0, t1; clip = false, master_attributes = false, kw...)
    get_data(path, t0, t1; clip = false, master_attributes = false, kw...)

Fetch data for a dataset (variable) within a time range (t0, t1).

A `path`-like format `<dataset>/<variable>` can also be used to specify the dataset and variable.

Set `master_attributes=true` to use master CDF attributes.
Set `clip=true` to restrict data to exact time bounds.

See `get_data_files` for caching options.
"""
function get_data end

function get_data(dataset, variable, t0, t1; clip = false, master_attributes = false, kw...)
    start_time = DateTime(t0)
    stop_time = DateTime(t1)
    file_paths = get_data_files(dataset, variable, start_time, stop_time; kw...)

    # Handle case where no data files are available (e.g., 404 error)
    if isempty(file_paths)
        @warn "No data available for $(dataset)/$(variable) in range $(start_time) to $(stop_time). Returning empty Variable from master CDF."
        master_cdf = find_master_cdf(dataset)
        return master_cdf[variable]
    end

    arrays = map(fp -> _get_variable_from_file(fp, variable), file_paths)
    metadata = !master_attributes ? nothing : begin
            master_cdf = find_master_cdf(dataset)
            master_cdf[variable].attrib
            # num = arrays[1].data.vdr.num
            # CDF.CommonDataFormat.vattrib(master_cdf.source, num)
        end
    var = ConcatCDFVariable(arrays; metadata)
    return clip ? var[start_time .. stop_time] : var
end

function get_data(path::AbstractString, start_time, stop_time; kw...)
    parts = split(path, '/', limit = 2)
    @assert length(parts) <= 2 "Path should be of the form <dataset> or <dataset>/<variable>"
    if length(parts) == 1
        return get_dataset(path, start_time, stop_time; kw...)
    else
        dataset, variable = String(parts[1]), String(parts[2])
        @assert !isempty(dataset) "dataset name cannot be empty"
        @assert !isempty(variable) "variable name cannot be empty"
        return get_data(dataset, variable, start_time, stop_time; kw...)
    end
end


function get_data(dataset, variable)
    return find_master_cdf(dataset)[variable]
end
#
