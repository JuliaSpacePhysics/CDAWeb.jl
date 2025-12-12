# Changelog

## Unreleased

### Changed

- `get_data` no longer supports the `orig` keyword.
- `get_data(dataset, variable, t0, t1; ...)` now always uses processed data files (`orig=false`).
- Preferred access pattern for a single variable in original files is now `get_data(dataset, t0, t1)["V"]`.
