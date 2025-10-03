# Get Variables
# This service provides descriptions of the variables that is available from a dataset.  The following table describes the HTTP request and response.

function get_variables(dataset)
    url = "$(ENDPOINT)/$(dataset)/variables"
    response = HTTP.get(url, HEADER)
    return JSON3.read(response.body).VariableDescription
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

Get a single dataset description by ID.

The value of `id` may be
- CDAS (e.g., `AC_H2_MFI`),
- DOI (e.g., `10.48322/fh85-fj47`),
- SPASE ResourceID (e.g., `spase://NASA/NumericalData/ACE/MAG/L2/PT1H`).

"""
get_dataset(id; kw...) = only(get_datasets(; id, kw...))
