---
name: cdaweb-metadata
description: >
  Explore CDAWeb dataset and variable metadata. Use this skill to find dataset IDs, inspect variables, or look up parameter descriptions for CDAWeb missions and instruments.
---

# CDAWeb Metadata Exploration

## Useful discovery functions

| Function                               | Purpose                         |
| -------------------------------------- | ------------------------------- |
| `get_observatory_groups()`             | List all mission groups         |
| `get_instruments()`                    | List instruments                |
| `get_instrument_types()`               | List instrument type categories |
| `get_datasets(; observatoryGroup=...)` | Datasets for a mission          |
| `get_dataset("ID")`                    | Full metadata for one dataset   |
| `get_variables("ID")`                  | All variable descriptions       |

Values are case-sensitive.

## Step: Find the dataset ID

`get_datasets` accepts ANDed filters: `observatoryGroup`, `instrumentType`, `observatory`, `instrument`, `id`.

```julia
using CDAWeb

# Filter by one or more parameters — all are combined with AND
datasets = get_datasets(; observatoryGroup="THEMIS")
# or more specific:
# datasets = get_datasets(; observatoryGroup="THEMIS", instrumentType="Particles (space)")

# Optionally narrow further by ID or label keywords
target = filter(d -> occursin("THD", d.Id) && occursin("SST", d.Id), datasets)

for d in target
    println(d.Id, " → ", d.Label)
end
```

Other useful filter fields: `Label`, `TimeInterval`.

## Step: Get variable metadata

Then:

```julia
vars = get_variables("THD_L2_SST")

# Show all variables
for v in vars
    println(v.Name, ": ", v.LongDescription)
end
```

Variable fields: `Name`, `ShortDescription`, `LongDescription`.

Filter for specific quantities:

```julia
# By name pattern
elec = filter(v -> occursin("pse", v.Name), vars)

# Or by description keyword
flux = filter(v -> occursin("flux", lowercase(v.LongDescription)), vars)
```

## Step: Dataset-level metadata

For full dataset metadata:

```julia
ds = get_dataset("THD_L2_SST")
# Useful fields: Id, Label, TimeInterval, PiName, Notes, DatasetLink
println(ds.Label)
println("Coverage: ", ds.TimeInterval.Start, " → ", ds.TimeInterval.End)
```

## Output format

Present results as:

1. **Dataset** — ID, label, time coverage
2. **Relevant variables** — name and description for each match, grouped by type
3. **Next step hint** — variable name(s) to pass to `get_data()`
