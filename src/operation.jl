# Internal function to read data from CDAS
function _cdas_read(key; dataview = "sp_phys", query...)
    url = "$(ENDPOINT)/$(dataview)/$(key)"
    return get_cached_json(url; use_cache = isempty(query), query...)
end

"""
    get_dataviews()

Get descriptions of available dataviews.
"""
get_dataviews() = get_cached_json(ENDPOINT)

"""
    get_instrument_types(; query...)

Get available instrument types.

See [Details](https://cdaweb.gsfc.nasa.gov/WebServices/REST/WebServices.html#Get_Instrument_Types) for available query parameters.
"""
get_instrument_types(; query...) = _cdas_read("instrumentTypes"; query...)

"""
    get_instruments(; query...)

Get descriptions of available instruments.

See [Details](https://cdaweb.gsfc.nasa.gov/WebServices/REST/WebServices.html#Get_Instruments) for available query parameters.
"""
get_instruments(; query...) = _cdas_read("instruments"; query...)

"""
    get_observatories(; query...)

Get descriptions of available observatories. 

See [Details](https://cdaweb.gsfc.nasa.gov/WebServices/REST/WebServices.html#Get_Observatories) for available query parameters.
"""
get_observatories(; query...) = _cdas_read("observatories"; query...)

"""
    get_observatory_groups(; query...)

Get descriptions of available observatory groups.

See [Details](https://cdaweb.gsfc.nasa.gov/WebServices/REST/WebServices.html#Get_Observatory_Groups) for available query parameters.
"""
get_observatory_groups(; query...) = _cdas_read("observatoryGroups"; query...)

"""
    get_observatory_groups_and_instruments(; query...)

Get descriptions of available observatory groups and instruments.

This is a convenience/performance alternative to making multiple calls to Get Observatory Groups, Get Observatories, and Get Instruments.

See [Details](https://cdaweb.gsfc.nasa.gov/WebServices/REST/WebServices.html#Get_Observatory_Groups_And_Instruments) for available query parameters.
"""
get_observatory_groups_and_instruments(; query...) = _cdas_read("observatoryGroupsAndInstruments"; query...)

"""
    get_inventory(dataset, t0, t1; dataview = "sp_phys")

Get descriptions of the available inventory for the `dataset`.

See [Details](https://cdaweb.gsfc.nasa.gov/WebServices/REST/WebServices.html#Get_Inventory).
"""
function get_inventory(dataset, t0, t1; dataview = "sp_phys")
    url = "$(ENDPOINT)/$(dataview)/datasets/$(dataset)/inventory/$(_format_time(t0)),$(_format_time(t1))"
    return _json_read1(HTTP.get(url, HEADER))
end

"""
    get_variables(dataset)

Get descriptions of available variables for the `dataset`.

See [Get Variables](https://cdaweb.gsfc.nasa.gov/WebServices/REST/#Get_Variables) for more details.
"""
get_variables(dataset) = get_cached_json("$(SP_ENDPOINT)/$(dataset)/variables")

function get_variable_names(dataset)
    master = _find_master_cdf(dataset)
    return if isnothing(master)
        getproperty.(get_variables(dataset), :Name)
    else
        filter(k -> var_type(master[k]) == "data", keys(master))
    end
end

"""
    get_datasets(; use_cache = true, query...)

Get descriptions of available datasets for the `query`.

See [Get Datasets](https://cdaweb.gsfc.nasa.gov/WebServices/REST/#Get_Datasets) for available query parameters.
"""
function get_datasets(; use_cache = true, query...)
    return get_cached_json(SP_ENDPOINT; use_cache, query...)
end

"""
    get_original_file_descs(id, start_time, stop_time; dataview = "sp_phys")

Get descriptive information about original data files from the `id` dataset. 

Original data files may lack updated meta-data and virtual variable values contained in files obtained from the other Get Data services.

See also [`get_data_file_descs`](@ref).
"""
function get_original_file_descs(id, t0, t1; dataview = "sp_phys")
    url = "$(ENDPOINT)/$(dataview)/datasets/$(id)/orig_data/$(_format_time(t0)),$(_format_time(t1))"
    return _json_read1(HTTP.get(url, HEADER))
end

"""
    get_data_file_descs(dataset, variables, t0, t1; dataview = "sp_phys", format = "cdf", query...)

Get descriptive information about the specified data file for the `dataset`, `variables`.

See [Get Data](https://cdaweb.gsfc.nasa.gov/WebServices/REST/#Get_Data_GET) for more details.
"""
function get_data_file_descs(dataset, variables, t0, t1; dataview = "sp_phys", format = "cdf", query...)
    var_str = variables isa AbstractString ? variables : join(variables, ",")
    url = "$(ENDPOINT)/$(dataview)/datasets/$(dataset)/data/$(_format_time(t0)),$(_format_time(t1))/$(var_str)"
    return _json_read1(HTTP.get(url, HEADER; query = (; format, query...)))
end
