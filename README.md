# CDAWeb

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg?logo=julia)](https://JuliaSpacePhysics.github.io/CDAWeb.jl/dev/)
[![DOI](https://zenodo.org/badge/1061976595.svg)](https://doi.org/10.5281/zenodo.17519096)

Julia interface to NASA's CDAWeb RESTful services for accessing space physics data.

## Quick Start

```julia
using Pkg; Pkg.add("CDAWeb")
using CDAWeb, Dates

display(get_datasets("PSP", "MAG", "RTN"))   # find datasets: id, time range, label
display(values(cda"OMNI_HRO_1MIN"))         # a dataset's data variables, with descriptions

x = cda"OMNI_HRO_1MIN/SYM_H"("2015-03-17", "2015-03-18")  # data in [t0, t1): a lazy CDFVariable
A = Array(x)              # FILLVAL and values outside VALIDMIN/VALIDMAX are NaN; time is the last dimension
t = DateTime.(times(x))
getmeta(x, "UNITS")       # ISTP attributes: CATDESC, UNITS, FILLVAL, DEPEND_1
```

## Data

```julia
t0, t1 = "2023-01-01", "2023-01-02"
B = CDAWeb.Dataset(id)[var]          # cda"AC_H0_MFI/BGSEc" for literals
getdata(B, t0, t1)                   # same as B(t0, t1)
getdata.(cda"AC_H0_MFI/BGSEc,Magnitude", t0, t1)
ds = cda"AC_H0_MFI"                  # CDAWeb.Dataset("AC_H0_MFI")
getdata(ds, t0, t1)                  # the whole dataset
keys(ds)                             # data variable names; values(ds) the variables
getmeta(B, "FIELDNAM")               # variable attributes from the master CDF, without fetching data
remotefiles(ds, t0, t1)              # original file URLs
CDAWeb.Dataset(id; direct = true)[var](t0, t1)  # one variable through CDAWeb's subsetting service, not whole files
```

Files are cached in `~/.cdaweb/` (or `$CDAWEB_DIR`); `clear_cache!()` clears it.

`keys`, `values` and `getmeta(B)` read the dataset's master CDF, fetched alone (about 100 KB) when not on disk; it may list variables the data files lack, or miss some they have.

## Discovery

```julia
get_datasets("THEMIS", "electric")          # CDAWeb.Datasets
get_variables("SYM-H"; dataset = "OMNI")    # CDAWeb.Variables
get_variables("density"; dataset = "MMS1 FPI brst")
get_inventory(id, t0, t1)                   # (start, stop) of each interval with data
```

- Each space-separated word of the terms must match a whole word of the dataset's id, label, mission, spacecraft or instrument, case-insensitively: plural `-s`/`-es` allowed, digits may follow (`"MMS"` finds `MMS1`), a trailing `*` makes a prefix (`"magnet*"`). Separators inside a word match any separator (`"SYM-H"` finds `SYM_H`); a `Regex` matches as given.
- `get_variables` terms must all match one data variable's name or description (`CATDESC`), and `dataset` terms its dataset as above. Past 20 datasets it reads the masters archive (560 MB), downloaded on first use, rather than a master each.
- When nothing matches, an info line gives each term's matches alone.
- Time ranges come from CDAS and may extend past the data; `get_inventory` gives the intervals with data.
- `display` shows a row per result, up to 80, variables under a line per dataset, then the matches per id prefix (spacecraft code) to narrow by; `show(stdout, MIME"text/plain"(), x)` shows all. Search variables with the quantity as terms and the mission, instrument and mode as `dataset`.
- `getmeta(ds)` is the dataset's CDAS entry: `Id`, `Label`, `TimeInterval.Start/End`, `PiName`, `Notes`, `Doi`, `SpaseResourceId`.
- CDAS metadata (the dataset list) is cached in `~/.cdaweb/metadata/` for a day.

## References

- [CDAS RESTful Web Services](https://cdaweb.gsfc.nasa.gov/WebServices/REST)
- [CDA_Webservice - speasy (Python)](https://github.com/SciQLop/speasy/blob/main/speasy/data_providers/cda/__init__.py)

## Elsewhere

- [`speasy`](https://github.com/SciQLop/speasy) pursues a similar goal with support for multiple data sources including AMDA and CSA. This package, however, focuses on finer control over cached data with better performance and offers straightforward, direct access to those files allowing offline access and reproducibility (see [speasy#237](https://github.com/SciQLop/speasy/issues/237) and [speasy#122](https://github.com/SciQLop/speasy/issues/122)).
- [xhelio-cdaweb](https://github.com/huangzesen/xhelio-cdaweb): NASA CDAWeb data access for heliophysics — MCP server + Python library
