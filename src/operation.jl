# Get Variables
# This service provides descriptions of the variables that is available from a dataset.  The following table describes the HTTP request and response.

"""
    get_variables(dataset)

Get descriptions of the variables that is available from the `dataset`.
"""
function get_variables(dataset)
    url = "$(ENDPOINT)/$(dataset)/variables"
    response = HTTP.get(url, HEADER)
    return JSON3.read(response.body).VariableDescription
end

function get_variable_names(dataset)
    master = _find_master_cdf(dataset)
    return if isnothing(master)
        getproperty.(get_variables(dataset), :Name)
    else
        filter(k -> var_type(master[k]) == "data", keys(master))
    end
end


"""
    get_datasets(; kw...)

Get descriptions of the datasets that are available from CDAS.

See [Get Datasets](https://cdaweb.gsfc.nasa.gov/WebServices/REST/#Get_Datasets) for available query parameters (keyword arguments).
"""
function get_datasets(; query...)
    response = HTTP.get(ENDPOINT, HEADER; query)
    return JSON3.read(response.body).DatasetDescription
end

"""
    get_dataset(id; kw...)

Get the dataset description by `id`.

The value of `id` may be
- CDAS (e.g., `AC_H2_MFI`),
- DOI (e.g., `10.48322/fh85-fj47`),
- SPASE ResourceID (e.g., `spase://NASA/NumericalData/ACE/MAG/L2/PT1H`).

"""
get_dataset(id; kw...) = only(get_datasets(; id, kw...))

"""
    get_dataset(id, start_time, stop_time; kw...)

Get the dataset by `id` between `start_time` and `stop_time`.

If no dataset is available for the specified time range, the corresponding master dataset is returned.
"""
function get_dataset(id, start_time, stop_time; kw...)
    file_paths = get_original_data_files(id, start_time, stop_time; kw...)
    return !isempty(file_paths) ? ConcatCDFDataset(file_paths) : begin
            @warn "No data available for $(id) in range $(start_time) to $(stop_time). Returning master CDF dataset."
            find_master_cdf(id)
        end
end

"""
    get_original_data_files(id, start_time, stop_time; kw...)

Get original data files from the `id` dataset. 

Original data files may lack updated meta-data and virtual variable values contained in files obtained from the other Get Data services. 
"""
function get_original_data_files(id, start_time, stop_time; kw...)
    return _get_data_files(DateTime(start_time), DateTime(stop_time), id; kw...)
end
