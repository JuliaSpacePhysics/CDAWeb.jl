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
keys(ds)  # data variable names
datasets = find_datasets("AC_H0")

# SpaceDataModel datasets/products, cached and clipped to [t0, t1)
t0, t1 = "2023-01-01", "2023-01-02"
getdata(ds, t0, t1)  # cda"AC_H0_MFI" == CDAWeb.Dataset("AC_H0_MFI"; direct = false)
B = cda"AC_H0_MFI/BGSEc" # == CDAWeb.Dataset("AC_H0_MFI")["BGSEc"]
getdata(B, t0, t1)                  # or B(t0, t1)
getdata.(cda"AC_H0_MFI/BGSEc,Magnitude", t0, t1)

remotefiles(cda"AC_H0_MFI", t0, t1)   # original file URLs

# Access master CDF metadata
find_master_cdf("AC_H0_MFI")["BGSEc"].metadata["FIELDNAM"]

# Direct access to CDF files with fine-grained control
files = get_data_files("AC_H0_MFI", "BGSEc", t0, t1;
                       fragment_period = Hour(12),  # Custom fragment size
                       disable_cache = false)       # Enable/disable caching
```

## Discovery

```julia
get_observatory_groups()   # also get_observatories, get_instruments, get_instrument_types
get_datasets(; observatoryGroup = "THEMIS", instrumentType = "Particles (space)")
get_datasets(; idPattern = "THD_L2_.*")   # server-side regex
get_variables("THD_L2_SST")               # Name, ShortDescription, LongDescription
```

- `get_datasets` filters are ANDed, case-sensitive, and match exact values. `id`, `observatoryGroup`, `instrumentType`, `observatory`, `instrument` filter a locally cached full list; any other query (`idPattern`, `startDate`, ...) goes to the server.
- Dataset entries carry `Id`, `Label`, `TimeInterval.Start/End`, `PiName`, `Notes`, `Doi`, `SpaseResourceId`; `getmeta(cda"ID")` returns the same entry.

## Features

**Agent skill**: at terminal, run `npx skills add JuliaSpacePhysics/CDAWeb.jl`

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
