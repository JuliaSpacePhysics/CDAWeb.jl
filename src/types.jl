"""
    CDAWeb.Dataset(id; direct = false, master_attributes = false)

The CDAWeb dataset `id`: a CDAS id (`AC_H2_MFI`), DOI (`10.48322/fh85-fj47`) or SPASE ResourceID
(`spase://NASA/NumericalData/ACE/MAG/L2/PT1H`); `ds[var]` is its variable.

`direct` fetches a variable through CDAWeb's subsetting service rather than indexing the whole
cached dataset; `master_attributes` (direct only) takes its attributes from the master CDF.
`getdata` keywords go to [`get_data_files`](@ref).
"""
struct Dataset <: AbstractDataset
    id::String
    direct::Bool
    master_attributes::Bool
end

Dataset(id; direct=false, master_attributes=false) = Dataset(_cdas_id(id), direct, master_attributes)

# Data endpoints, cache entries and master CDFs are keyed by the CDAS id
_cdas_id(id) = startswith(id, r"10\.|spase://") ? String(only(get_datasets(; id)).Id) : String(id)

SpaceDataModel.name(ds::Dataset) = ds.id
SpaceDataModel.getmeta(ds::Dataset) = only(get_datasets(; id = ds.id))
SpaceDataModel.remotefiles(ds::Dataset, t0, t1) = _get_file_urls_from_api(ds.id, DateTime(t0), DateTime(t1))
Base.keys(ds::Dataset) = get_variable_names(ds.id)
SpaceDataModel.getdata(ds::Dataset, t0::DateTime, t1::DateTime; kw...) = _get_dataset(ds.id, t0, t1; kw...)

function SpaceDataModel.getdata(p::Product{Dataset}, t0::DateTime, t1::DateTime; kw...)
    ds = parent(p)
    return ds.direct ? _get_data(ds.id, p.variable, t0, t1; ds.master_attributes, kw...) :
           getdata(ds, t0, t1; kw...)[p.variable]
end

"""
    cda"dataset"
    cda"dataset/variable"
    cda"dataset/variable1,variable2"

`CDAWeb.Dataset(dataset)`, its variable `Product`, or a `Vector` of them.

# Examples
```julia
B = cda"OMNI_COHO1HR_MERGED_MAG_PLASMA/BR"
B(t0, t1)
ps = cda"OMNI_COHO1HR_MERGED_MAG_PLASMA/BR,N"
getdata.(ps, t0, t1)
```
"""
macro cda_str(s)
    id, vars = _split_path(s)
    contains(id, ',') && throw(ArgumentError("expected \"dataset/variable1,variable2\", got \"$s\""))
    isnothing(vars) && return :(Dataset($id))
    names = String.(strip.(split(vars, ',')))
    return length(names) == 1 ? :(Dataset($id)[$(only(names))]) : :(let ds = Dataset($id); [ds[v] for v in $names] end)
end
