# Changelog

## Unreleased

### Added

- `CDAWeb.Dataset <: SpaceDataModel.AbstractDataset`: `getdata(CDAWeb.Dataset(id)[var], t0, t1)`.
- `getmeta(ds)` and `remotefiles(ds, t0, t1)` for `CDAWeb.Dataset`, which also accepts a DOI or SPASE ResourceID.

### Removed

- `CDAWebProduct` and `CDAWebProducts`: use `cda"..."` or `CDAWeb.Dataset(id)[var]`.
- `get_dataset`: use `getmeta(cda"id")` for the description and `cda"id"(t0, t1)` for data.
- `get_data` and the `clip` keyword; data is always restricted to `[t0, t1)`.
  - `get_data(id, var, t0, t1)`: `cda"id/var"(t0, t1)`, or `CDAWeb.Dataset(id; direct = true)[var](t0, t1)` for CDAWeb's subsetting service (virtual variables).
  - `get_data(id, t0, t1)`: `cda"id"(t0, t1)`.
  - `get_data(id, var)`: `find_master_cdf(id)[var]`.

### Changed

- `cda"dataset/var"` returns a `SpaceDataModel` `Product` (a `CDAWeb.Dataset` for a bare dataset id); `cda"dataset/a,b"` a `Vector` of them.
- `clip = true` and `cda` products restrict data to `[t0, t1)`: a record at `t1` is no longer included.

- `find_datasets` always returns a `Vector`, also for an exact master CDF filename.

## [0.2.0] - 2025-12-13

### Changed

- **Breaking**: `get_data` no longer supports the `orig` keyword.
  - Preferred access pattern for a single variable in original files is now `get_data(dataset, t0, t1)["V"]`.
- **Breaking**: `get_data(dataset, variable, t0, t1; ...)` now always uses processed data files (`orig=false`).

[Unreleased]: https://github.com/JuliaSpacePhysics/VelocityDistributionFunctions.jl/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/JuliaSpacePhysics/VelocityDistributionFunctions.jl/compare/v0.1.0...v0.2.0
