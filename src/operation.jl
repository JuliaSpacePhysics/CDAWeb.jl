"""
    get_dataviews()

Get descriptions of the dataviews that are available from CDAS.
"""
function get_dataviews()
    response = HTTP.get(ENDPOINT, HEADER)
    return JSON3.read(response.body).DataviewDescription
end

"""
    get_instrument_types(; dataview = "sp_phys", query...)

Get descriptions of the instrument types that are available from CDAS.

See [Details](https://cdaweb.gsfc.nasa.gov/WebServices/REST/WebServices.html#Get_Instrument_Types) for available query parameters.
"""
function get_instrument_types(; dataview = "sp_phys", query...)
    url = "$(ENDPOINT)/$(dataview)/instrumentTypes"
    response = HTTP.get(url, HEADER; query)
    return JSON3.read(response.body).InstrumentTypeDescription
end

"""
    get_instruments(; dataview = "sp_phys", query...)

Get descriptions of the instruments that are available from CDAS.

See [Details](https://cdaweb.gsfc.nasa.gov/WebServices/REST/WebServices.html#Get_Instruments) for available query parameters.
"""
function get_instruments(; dataview = "sp_phys", query...)
    url = "$(ENDPOINT)/$(dataview)/instruments"
    response = HTTP.get(url, HEADER; query)
    return JSON3.read(response.body).InstrumentDescription
end

"""
    get_observatories(; dataview = "sp_phys", query...)

Get descriptions of the observatories that are available from CDAS. 

See [Details](https://cdaweb.gsfc.nasa.gov/WebServices/REST/WebServices.html#Get_Observatories) for available query parameters.
"""
function get_observatories(; dataview = "sp_phys", query...)
    url = "$(ENDPOINT)/$(dataview)/observatories"
    response = HTTP.get(url, HEADER; query)
    return JSON3.read(response.body).ObservatoryDescription
end

"""
    get_observatory_groups(; dataview = "sp_phys", query...)

Get descriptions of the observatory groups that are available from CDAS.

See [Details](https://cdaweb.gsfc.nasa.gov/WebServices/REST/WebServices.html#Get_Observatory_Groups) for available query parameters.
"""
function get_observatory_groups(; dataview = "sp_phys", query...)
    url = "$(ENDPOINT)/$(dataview)/observatoryGroups"
    response = HTTP.get(url, HEADER; query)
    return JSON3.read(response.body).ObservatoryGroupDescription
end

"""
    get_observatory_groups_and_instruments(; dataview = "sp_phys", query...)

Get descriptions of the observatory groups and instruments that are available from CDAS.

This is a convenience/performance alternative to making multiple calls to Get Observatory Groups, Get Observatories, and Get Instruments.

See [Details](https://cdaweb.gsfc.nasa.gov/WebServices/REST/WebServices.html#Get_Observatory_Groups_And_Instruments) for available query parameters.
"""
function get_observatory_groups_and_instruments(; dataview = "sp_phys", query...)
    url = "$(ENDPOINT)/$(dataview)/observatoryGroupsAndInstruments"
    response = HTTP.get(url, HEADER; query)
    return JSON3.read(response.body).ObservatoryGroupInstrumentDescription
end

# Get Inventory
"""
    get_inventory(dataset, t0, t1; dataview = "sp_phys")

Get descriptions of the inventory that is available from CDAS.

See [Details](https://cdaweb.gsfc.nasa.gov/WebServices/REST/WebServices.html#Get_Inventory).
"""
function get_inventory(dataset, t0, t1; dataview = "sp_phys")
    url = "$(ENDPOINT)/$(dataview)/datasets/$(dataset)/inventory/$(_format_time(t0)),$(_format_time(t1))"
    response = HTTP.get(url, HEADER)
    return JSON3.read(response.body).InventoryDescription
end

# Get Variables
# This service provides descriptions of the variables that is available from a dataset.  The following table describes the HTTP request and response.

"""
    get_variables(dataset)

Get descriptions of the variables that is available from the `dataset`.

See [Get Variables](https://cdaweb.gsfc.nasa.gov/WebServices/REST/#Get_Variables) for more details.
"""
function get_variables(dataset)
    url = "$(SP_ENDPOINT)/$(dataset)/variables"
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

See [Get Datasets](https://cdaweb.gsfc.nasa.gov/WebServices/REST/#Get_Datasets) for available query parameters.
"""
function get_datasets(; query...)
    response = HTTP.get(SP_ENDPOINT, HEADER; query)
    return JSON3.read(response.body).DatasetDescription
end

"""
    get_original_file_descs(id, start_time, stop_time; dataview = "sp_phys")

Get descriptive information about original data files from the `id` dataset. 

Original data files may lack updated meta-data and virtual variable values contained in files obtained from the other Get Data services.

See also [`get_data_file_descs`](@ref).
"""
function get_original_file_descs(id, t0, t1; dataview = "sp_phys")
    url = "$(ENDPOINT)/$(dataview)/datasets/$(id)/orig_data/$(_format_time(t0)),$(_format_time(t1))"
    response = HTTP.get(url, HEADER)
    return JSON3.read(response.body).FileDescription
end

"""
    get_data_file_descs(dataset, variables, t0, t1; dataview = "sp_phys", format = "cdf", query...)

Get descriptive information about the specified data file for the `dataset`, `variables`.

See [Get Data](https://cdaweb.gsfc.nasa.gov/WebServices/REST/#Get_Data_GET) for more details.
"""
function get_data_file_descs(dataset, variables, t0, t1; dataview = "sp_phys", format = "cdf", query...)
    var_str = variables isa AbstractString ? variables : join(variables, ",")
    url = "$(ENDPOINT)/$(dataview)/datasets/$(dataset)/data/$(_format_time(t0)),$(_format_time(t1))/$(var_str)"
    response = HTTP.get(url, HEADER; query = (; format, query...))
    return JSON3.read(response.body).FileDescription
end
