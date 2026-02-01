```@meta
CurrentModule = CDAWeb
```

# CDAWeb

[![DOI](https://zenodo.org/badge/1061976595.svg)](https://doi.org/10.5281/zenodo.17519096)
[![version](https://juliahub.com/docs/General/CDAWeb/stable/version.svg)](https://juliahub.com/ui/Packages/General/CDAWeb)

Julia interface to NASA's [Coordinated Data Analysis Web](https://cdaweb.gsfc.nasa.gov/) (CDAWeb) for accessing space physics data.

## Installation

```julia
using Pkg
Pkg.add("CDAWeb")
```

## Quick Example

```@example quick_example
using CDAWeb
using Dates

# Get dataset description
get_dataset("AC_H0_MFI")
```

```@example quick_example
# Get dataset within the time range and display its attributes
ds = get_data("AC_H0_MFI", "2023-01-01", "2023-01-02")
ds.attrib
```

```@example quick_example
# Fetch solar wind velocity data from OMNI dataset
dataset = "OMNI_COHO1HR_MERGED_MAG_PLASMA"
t0 = DateTime(2020, 1, 1) # Start time
t1 = DateTime(2020, 1, 2) # End time    
data = get_data(dataset, "V", t0, t1) # Data is automatically cached for faster subsequent access
```

Retrieve the original monthly data files and clip to the exact requested time range.

```@example quick_example
data = get_data(dataset, t0, t1; clip = true)["V"]
```

## Additional Features

### Get Metadata from Web Services

Access metadata directly from CDAWeb's RESTful services:

```@example quick_example
# Get descriptions of the instrument types that are available from CDAS.
instrument_types = get_instrument_types()
```

See also [`get_dataviews`](@ref), [`get_datasets`](@ref), [`get_instruments`](@ref), [`get_instrument_types`](@ref), [`get_observatories`](@ref), [`get_observatory_groups`](@ref), [`get_observatory_groups_and_instruments`](@ref), [`get_original_file_descs`](@ref), and [`get_data_file_descs`](@ref). These functions are convenience wrappers around the CDAS RESTful Web Services, closely matching the original API.

### Accessing Master CDF Metadata

Retrieve metadata without specifying a time range to access the master CDF file:

```@example quick_example
# Update/download the master CDF files
CDAWeb.update_master_cdf()
# Returns metadata from the master CDF for the ACE magnetic field dataset
get_data("AC_H0_MFI", "BGSEc")
```

### Finding Available Datasets

Search for datasets matching a pattern:

```@example quick_example
# Find all ACE H0 (high resolution) datasets
find_datasets("AC_H0")
```

### Cache Management

View cache metadata to inspect what data has been cached locally:

```@setup quick_example
using PrettyTables.Tables: columns, columnnames
using PrettyTables: pretty_table

# Helper function for creating scrollable HTML tables
function scrollable_table(data; kwargs...)
    column_labels = columnnames(columns(data)) |> collect
    table_html = pretty_table(String, data; backend = :html,
        maximum_column_width="10", column_labels, kwargs...)
    """<div style="overflow-x: auto; max-height: 400px; overflow-y: auto;">
    $table_html
    </div>""" |> Base.HTML
end
```

```@example quick_example
# Show metadata for web-served (processed) cached files
CDAWeb.cache_metadata(false)  |> scrollable_table
```

```@example quick_example
# Show metadata for original CDF cached files
CDAWeb.cache_metadata(true)  |> scrollable_table
```

## API Reference

```@index
```

```@autodocs
Modules = [CDAWeb]
```
