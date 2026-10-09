# CDAWeb

[![Dev](https://img.shields.io/badge/docs-dev-blue.svg?logo=julia)](https://JuliaSpacePhysics.github.io/CDAWeb.jl/dev/) [![DOI](https://zenodo.org/badge/1061976595.svg)](https://doi.org/10.5281/zenodo.17519096)

Julia interface to NASA's CDAWeb RESTful services for accessing space physics data.

## Quick Start

```julia
using Pkg; Pkg.add("CDAWeb")
using CDAWeb, Dates

ds = cda"OMNI_HRO_1MIN"
display(values(ds))         # data variables with descriptions, from the master CDF (data files may lack some); keys(ds) the names
t0, t1 = "2023-01-01", "2023-01-02"
var = cda"OMNI_HRO_1MIN/SYM_H"  # == `ds["SYM_H"]`
getmeta(var, "CATDESC")   # ISTP attributes: CATDESC, FIELDNAM, UNITS, FILLVAL, DEPEND_1

getdata(ds, t0, t1)  # the whole dataset
x = getdata(var, t0, t1)  # == `var(t0, t1)`: data in [t0, t1), a lazy CDFVariable
A = Array(x)              # FILLVAL and values outside VALIDMIN/VALIDMAX are NaN; time is the last dimension
t = times(x)
getdim(x, 1)              # values along dimension 1: its DEPEND_1 (e.g. a spectrogram's energies) or `axes(x, 1)`
getmeta(x, "VALIDMIN")    # attributes of the fetched files, which may differ from the master CDF's
BGSEc, Magnitude = getdata.(cda"AC_H0_MFI/BGSEc,Magnitude", t0, t1)
```

Files are cached in `~/.cdaweb/` (or `$CDAWEB_DIR`); `clear_cache!()` clears it.

## Discovery

```julia
display(get_datasets("PSP", "MAG", "RTN"))   # find datasets: id, time range, label
get_variables(; dataset = "SOLO SWA PAS")   # every data variable of every matching dataset, with descriptions
get_variables("density"; dataset = "MMS1 FPI brst")
```

- Each space-separated word of the terms must match a whole word of the dataset's id, label, mission, spacecraft or instrument, case-insensitively: plural `-s`/`-es` allowed, a trailing `*` makes a prefix (`"magnet*"`). Separators inside a word match any separator (`"SYM-H"` finds `SYM_H`); a `Regex` matches as given.
- `get_variables` terms must all match one data variable's name or description (`CATDESC`), and `dataset` terms its dataset as above.
- Datasets whose mission or spacecraft match more terms come first (`"Wind"` lists `WI_*` before ACE's "Solar Wind Experiment"), single-mission before merged (OMNI), then by id.
- When nothing matches, an info line gives each term's matches alone.
- `display` shows a row per result, up to 80 with labels cut at 160 characters, variables under a line per dataset, then the matches per id prefix (spacecraft code) to narrow by; `show(stdout, MIME"text/plain"(), x)` shows all.
- `getmeta(ds)` is the dataset's CDAS entry: `Id`, `Label`, `TimeInterval.Start/End`, `PiName`, `Notes`, `Doi`, `SpaseResourceId`.
- CDAS metadata (the dataset list) is cached in `~/.cdaweb/metadata/` for a day.

## References

- [CDAS RESTful Web Services](https://cdaweb.gsfc.nasa.gov/WebServices/REST)
- [CDA_Webservice - speasy (Python)](https://github.com/SciQLop/speasy/blob/main/speasy/data_providers/cda/__init__.py)

## Elsewhere

- [`speasy`](https://github.com/SciQLop/speasy) pursues a similar goal with support for multiple data sources including AMDA and CSA. This package, however, focuses on finer control over cached data with better performance and offers straightforward, direct access to those files allowing offline access and reproducibility (see [speasy#237](https://github.com/SciQLop/speasy/issues/237) and [speasy#122](https://github.com/SciQLop/speasy/issues/122)).
- [xhelio-cdaweb](https://github.com/huangzesen/xhelio-cdaweb): NASA CDAWeb data access for heliophysics — MCP server + Python library
