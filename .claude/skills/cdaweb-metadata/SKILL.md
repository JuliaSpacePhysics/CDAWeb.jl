---
name: cdaweb-metadata
description: >
  Explore CDAWeb dataset and variable metadata. Use this skill to find dataset IDs, inspect variables, or look up parameter descriptions for CDAWeb missions and instruments.
---

# CDAWeb Metadata Exploration

API reference: CDAWeb.jl README, section "Discovery" (`joinpath(pkgdir(CDAWeb), "README.md")` or <https://github.com/JuliaSpacePhysics/CDAWeb.jl#discovery>).

Filter values must match CDAWeb's spelling exactly; when a guess returns nothing, list the valid values (`get_observatory_groups()`, `get_instrument_types()`, ...) instead of retrying variants.
Mission datasets usually differ by probe/level/instrument in the `Id` (e.g. `THD_L2_SST`), so filter the returned list by `Id`/`Label` substrings.
Search variables by `LongDescription` keyword as well as by `Name`; names are terse and mission-specific.

