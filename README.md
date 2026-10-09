# CDAWeb

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg?logo=julia)](https://JuliaSpacePhysics.github.io/CDAWeb.jl/dev/)
[![DOI](https://zenodo.org/badge/1061976595.svg)](https://doi.org/10.5281/zenodo.17519096)

Julia interface to NASA's CDAWeb RESTful services for accessing space physics data.

## Quick Start

```julia
using Pkg; Pkg.add("CDAWeb")
using CDAWeb

# Get dataset metadata as JSON.Object
ds = cda"AC_H0_MFI"
getmeta(ds)
keys(ds)  # data variable names; values(ds) the variables

# Data, cached and clipped to [t0, t1)
t0, t1 = "2023-01-01", "2023-01-02"
getdata(ds, t0, t1)  # cda"AC_H0_MFI" == CDAWeb.Dataset("AC_H0_MFI"; direct = false)
B = cda"AC_H0_MFI/BGSEc" # == CDAWeb.Dataset("AC_H0_MFI")["BGSEc"]
getdata(B, t0, t1)                  # or B(t0, t1)
getdata.(cda"AC_H0_MFI/BGSEc,Magnitude", t0, t1)

remotefiles(cda"AC_H0_MFI", t0, t1)   # original file URLs

# Variable attributes from the master CDF, without fetching data
getmeta(B, "FIELDNAM")

# Direct access to CDF files with fine-grained control
files = get_data_files("AC_H0_MFI", "BGSEc", t0, t1;
                       fragment_period = Hour(12),  # Custom fragment size
                       disable_cache = false)       # Enable/disable caching
```

## Discovery

```julia
get_datasets("THEMIS", "electric")          # CDAWeb.Datasets
get_variables("SYM-H"; dataset = "OMNI")    # CDAWeb.Variables
get_variables("density"; dataset = "MMS1 FPI brst")
values(cda"THD_L2_SST")                     # data variables, displayed with descriptions
get_inventory(id, t0, t1)                   # (start, stop) of each interval with data
```

- Each space-separated word of the terms must match a whole word of the dataset's id, label, mission, spacecraft or instrument, case-insensitively: plural `-s`/`-es` allowed, digits may follow (`"MMS"` finds `MMS1`), a trailing `*` makes a prefix (`"magnet*"`). Separators inside a word match any separator (`"SYM-H"` finds `SYM_H`); a `Regex` matches as given.
- `get_variables` terms must all match one data variable's name or description (`CATDESC`), and `dataset` terms its dataset as above. Past 20 datasets it reads the masters archive (560 MB), downloaded on first use, rather than a master each.
- When nothing matches, an info line gives each term's matches alone.
- Time ranges come from CDAS and may extend past the data; `get_inventory` gives the intervals with data.
- `keys`, `values` and `getmeta(ds[var])` read the dataset's master CDF, fetched alone (about 100 KB) when not on disk; it may list variables the data files lack, or miss some they have.
- `getmeta(ds)` is the dataset's CDAS entry: `Id`, `Label`, `TimeInterval.Start/End`, `PiName`, `Notes`, `Doi`, `SpaseResourceId`.
- CDAS metadata (the dataset list) is cached in `~/.cdaweb/metadata/` for a day.

## Features

- Local cache system to avoid redundant downloads with fine-grained control
  - **Automatic cache management**: Downloaded files and their index live in `~/.cdaweb/`, or `$CDAWEB_DIR` if set
  - **Fragment-based caching**: Splits time ranges into fixed-duration fragments (default 24 hours) for efficient reuse across overlapping queries
  - **Manual cache control**: `CDAWeb.cache_metadata()` and `CDAWeb.clear_cache!()` for explicit management of cache metadata
- **Efficient data access**: Data and metadata are memory-mapped and lazily represented using [CommonDataFormat.jl](https://github.com/JuliaSpacePhysics/CommonDataFormat.jl)


## References

- [CDAS RESTful Web Services](https://cdaweb.gsfc.nasa.gov/WebServices/REST)
- [CDA_Webservice - speasy (Python)](https://github.com/SciQLop/speasy/blob/main/speasy/data_providers/cda/__init__.py)

## Elsewhere

- [`speasy`](https://github.com/SciQLop/speasy) pursues a similar goal with support for multiple data sources including AMDA and CSA. This package, however, focuses on finer control over cached data with better performance and offers straightforward, direct access to those files allowing offline access and reproducibility (see [speasy#237](https://github.com/SciQLop/speasy/issues/237) and [speasy#122](https://github.com/SciQLop/speasy/issues/122)).
- [xhelio-cdaweb](https://github.com/huangzesen/xhelio-cdaweb): NASA CDAWeb data access for heliophysics — MCP server + Python library
