```@meta
CurrentModule = CDAWeb
```

# CDAWeb

Documentation for [CDAWeb](https://github.com/JuliaSpacePhysics/CDAWeb.jl).

## Installation

```julia
using Pkg
Pkg.add("https://github.com/JuliaSpacePhysics/CDAWeb.jl")
```

## Quick Example

```@example quick_example
using CDAWeb
using Dates

# Fetch solar wind velocity data from OMNI dataset
dataset = "OMNI_COHO1HR_MERGED_MAG_PLASMA"
t0 = DateTime(2020, 1, 1) # Start time
t1 = DateTime(2020, 1, 2) # End time    
data = get_data(dataset,"V",t0,t1)
# Data is automatically cached for faster subsequent access
```

Retrieve the original monthly data files and clip to the exact requested time range.

```@example quick_example
data = get_data(dataset,"V",t0,t1; orig = true, clip=true)
```

## Additional Features

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

### Listing Data Files

Get the list of CDF files for a specific dataset and variable within a time range:

```@example quick_example
# Returns URLs of data files covering the specified date range
get_data_files("AC_H0_MFI", "BGSEc", "2023-01-01", "2023-01-02")
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
