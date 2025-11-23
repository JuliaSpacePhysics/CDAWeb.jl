# CDAWeb

[![DOI](https://zenodo.org/badge/1061976595.svg)](https://doi.org/10.5281/zenodo.17519096)

[![version](https://juliahub.com/docs/General/CDAWeb/stable/version.svg)](https://juliahub.com/ui/Packages/General/CDAWeb)
[![Build Status](https://github.com/JuliaSpacePhysics/CDAWeb.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/JuliaSpacePhysics/CDAWeb.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/JuliaSpacePhysics/CDAWeb.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/JuliaSpacePhysics/CDAWeb.jl)

Julia interface to NASA's CDAWeb RESTful services for accessing space physics data.

**Installation**: at the Julia REPL, run `using Pkg; Pkg.add("CDAWeb")`

**Documentation**: [![Dev](https://img.shields.io/badge/docs-dev-blue.svg?logo=julia)](https://JuliaSpacePhysics.github.io/CDAWeb.jl/dev/)

## Features

- Local cache system to avoid redundant downloads with fine-grained control
    - **Automatic cache management**: Metadata persisted to disk on exit, loaded on startup (Cache location: `~/.cdaweb/data/`)
    - **Fragment-based caching**: Splits time ranges into fixed-duration fragments (default 24 hours) for efficient reuse across overlapping queries
    - **Manual cache control**: `CDAWeb.cache_metadata()`, `CDAWeb.clear_cache!()`, and `CDAWeb.persist_cache!()` for explicit management of cache metadata
- **Efficient data access**: Data is memory-mapped and lazily represented using [CommonDataFormat.jl](https://github.com/JuliaSpacePhysics/CommonDataFormat.jl) for super fast querying and loading

### Data Access

```julia
using CDAWeb

# Get dataset description
dataset = get_dataset("AC_H0_MFI")
# Get dataset within the time range
dataset = get_dataset("AC_H0_MFI", "2023-01-01", "2023-01-02")

# Fetch variable data with automatic caching
data = get_data("AC_H0_MFI", "BGSEc", "2023-01-01", "2023-01-02")

# Access master CDF metadata
master_var = get_data("AC_H0_MFI", "BGSEc")

# Find datasets by name
datasets = find_datasets("AC_H0")

# Direct access to CDF files with fine-grained control
files = get_data_files("AC_H0_MFI", "BGSEc", "2023-01-01", "2023-01-02";
                       fragment_period = Hour(12),  # Custom fragment size
                       disable_cache = false)       # Enable/disable caching
```


## References

- [CDAS RESTful Web Services](https://cdaweb.gsfc.nasa.gov/WebServices/REST)
- [CDA_Webservice - speasy (Python)](https://github.com/SciQLop/speasy/blob/main/speasy/data_providers/cda/__init__.py)

## Elsewhere

- [`speasy`](https://github.com/SciQLop/speasy) pursues a similar goal, providing a similar `get_data` API to find and load space physics data. Speasy is more feature-complete, supporting multiple data sources such as AMDA and CSA. This package, however, focuses on finer control over cached data and offers straightforward, direct access to those files allowing offline access and reproducibility (see [speasy#237](https://github.com/SciQLop/speasy/issues/237) and [speasy#122](https://github.com/SciQLop/speasy/issues/122)).