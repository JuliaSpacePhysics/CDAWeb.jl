# Changelog

## Unreleased

### Added

- `CDAWeb.Dataset <: SpaceDataModel.AbstractDataset`: `getdata(CDAWeb.Dataset(id)[var], t0, t1)`.
- `getmeta(ds)` and `remotefiles(ds, t0, t1)` for `CDAWeb.Dataset`, which also accepts a DOI or SPASE ResourceID.
- `keys(ds)` and `values(ds)` list a dataset's data variables: names and `CDAWeb.Variable`s.
- `get_variables(terms...; dataset)` finds data variables by name or description.

### Removed

- **Breaking**: exports of `get_dataviews`, `get_instruments`, `get_instrument_types`, `get_observatories`, `get_observatory_groups`, `get_observatory_groups_and_instruments`; qualify them with `CDAWeb.`.
- `CDAWebProduct` and `CDAWebProducts`: use `cda"..."` or `CDAWeb.Dataset(id)[var]`.
- `get_dataset`: use `getmeta(cda"id")` for the description and `cda"id"(t0, t1)` for data.
- `get_data` and the `clip` keyword; data is always restricted to `[t0, t1)`.
  - `get_data(id, var, t0, t1)`: `cda"id/var"(t0, t1)`, or `CDAWeb.Dataset(id; direct = true)[var](t0, t1)` for CDAWeb's subsetting service (virtual variables).
  - `get_data(id, t0, t1)`: `cda"id"(t0, t1)`.
  - `get_data(id, var)`: `find_master_cdf(id)[var]`.
- **Breaking**: `find_datasets`: `[find_master_cdf(ds.id) for ds in get_datasets("AC_H0")]`.

### Changed

- `display` of `get_datasets` and `get_variables` results and `values(ds)` shows a row each, variables with their descriptions; past 80 rows it counts matches per id prefix to narrow by.
- **Breaking**: `get_variables(terms...; dataset)` searches variables by terms and returns `CDAWeb.Variable`s; `values(cda"id")` lists a dataset's, `getmeta(cda"id/var")` gives attributes.
- **Breaking**: `get_datasets(terms...)` searches by terms, replacing CDAS query keywords, and returns `CDAWeb.Dataset`s; `getmeta(ds)` is the former entry.
- `CDAWeb.Dataset(id)` validates its id against the dataset list.
- CDAS metadata (the dataset list) is cached on disk for a day, so `cda"..."` works offline on cached data.
- Virtual variables (computed by CDAWeb, e.g. THEMIS `the_peif_en_efluxQ`) fetch through CDAWeb's service instead of failing on the placeholder in cached files.
- **Breaking**: `get_inventory` returns `(start, stop)` `DateTime` tuples.
- `cda"dataset/var"` returns a `CDAWeb.Variable` (a `CDAWeb.Dataset` for a bare dataset id); `cda"dataset/a,b"` a `Vector` of them.
- `clip = true` and `cda` products restrict data to `[t0, t1)`: a record at `t1` is no longer included.

## [0.2.0] - 2025-12-13

### Changed

- **Breaking**: `get_data` no longer supports the `orig` keyword.
  - Preferred access pattern for a single variable in original files is now `get_data(dataset, t0, t1)["V"]`.
- **Breaking**: `get_data(dataset, variable, t0, t1; ...)` now always uses processed data files (`orig=false`).

[Unreleased]: https://github.com/JuliaSpacePhysics/VelocityDistributionFunctions.jl/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/JuliaSpacePhysics/VelocityDistributionFunctions.jl/compare/v0.1.0...v0.2.0
