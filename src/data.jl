const CDAWEB_BASE_URL = "https://cdaweb.gsfc.nasa.gov/WS/cdasr/1"
const DATA_VIEWS_PATH = "dataviews/sp_phys/datasets"
const HEADER = ["Accept" => "application/json"]

struct CDAWebError <: Exception
    message::String
end

function check_response(response)
    return if response.status != 200
        throw(CDAWebError("HTTP $(response.status): $(response.body)"))
    end
end

function _split_product(product::AbstractString)
    parts = split(product, '/', limit = 2)
    @assert length(parts) == 2 "product should be of the form dataset/variable"
    dataset, variable = String(parts[1]), String(parts[2])
    @assert !isempty(dataset) "dataset name cannot be empty"
    @assert !isempty(variable) "variable name cannot be empty"
    return dataset, variable
end

_format_time(time) = Dates.format(time, "yyyymmddTHHMMSS") * "Z"

function _build_request_url(dataset, variable, start_time, stop_time; format = "cdf")
    start_str = _format_time(start_time)
    stop_str = _format_time(stop_time)
    return "$(CDAWEB_BASE_URL)/$(DATA_VIEWS_PATH)/$(dataset)/data/$(start_str),$(stop_str)/$(variable)?format=$(format)"
end

function _build_request_url(dataset, start_time, stop_time)
    start_str = _format_time(start_time)
    stop_str = _format_time(stop_time)
    return "$(CDAWEB_BASE_URL)/$(DATA_VIEWS_PATH)/$(dataset)/orig_data/$(start_str),$(stop_str)/"
end


function _get_variable_from_file(file_path::String, variable::String)
    dataset = CDFDataset(file_path)
    try
        dataset[variable]
    catch
        available_vars = collect(keys(dataset))
        throw("Variable '$(variable)' not found in file. Available variables: $(available_vars)")
    end
end

# https://github.com/SciQLop/PyISTP/blob/main/pyistp/_impl.py#L16

"""
Fetch data for a dataset variable within a time range.

Set `master_attributes=true` to use master CDF attributes.
Set `clip=true` to restrict data to exact time bounds.

See `get_data_files` for caching options.
"""
function get_data(dataset, variable, start_time, stop_time; clip = false, master_attributes = false, kw...)
    start_time = DateTime(start_time)
    stop_time = DateTime(stop_time)
    file_paths = get_data_files(dataset, variable, start_time, stop_time; kw...)
    arrays = map(fp -> _get_variable_from_file(fp, variable), file_paths)
    metadata = !master_attributes ? nothing : begin
        master_cdf = find_master_cdf(dataset)
        master_cdf[variable].attrib
        # num = arrays[1].data.vdr.num
        # CDF.CommonDataFormat.vattrib(master_cdf.source, num)
    end
    var = ConcatCDFVariable(arrays; metadata)
    return if clip
        indices = CDFDatasets.find_indices(var, start_time, stop_time)
        selectdim(var, ndims(var), indices)
    else
        var
    end
end

function get_data(product::AbstractString, start_time, stop_time)
    dataset, variable = _split_product(product)
    return get_data(dataset, variable, start_time, stop_time)
end


function get_data(dataset, variable)
    return find_master_cdf(dataset)[variable]
end
# 