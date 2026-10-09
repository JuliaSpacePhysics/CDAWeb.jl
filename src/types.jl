"""
    CDAWeb.Dataset(id; direct = false, master_attributes = false)

The CDAWeb dataset `id`: a CDAS id (`AC_H2_MFI`), DOI (`10.48322/fh85-fj47`) or SPASE ResourceID
(`spase://NASA/NumericalData/ACE/MAG/L2/PT1H`); `ds[var]` is its [`CDAWeb.Variable`](@ref).

`direct` fetches a variable through CDAWeb's subsetting service rather than indexing the whole
cached dataset; `master_attributes` (direct only) takes its attributes from the master CDF.
`getdata` keywords go to [`get_data_files`](@ref).
"""
struct Dataset <: AbstractDataset
    id::String
    direct::Bool
    master_attributes::Bool
    metadata::JSON.Object{String, Any}
end

Dataset(id::AbstractString; kw...) = Dataset(_dataset_row(id); kw...)
Dataset(row::JSON.Object; direct=false, master_attributes=false) = Dataset(row["Id"], direct, master_attributes, row)

# Data endpoints, cache entries and master CDFs are keyed by the CDAS id, so aliases resolve to its row
function _dataset_row(id)
    rows = get_cached_json(SP_ENDPOINT; id)
    isempty(rows) && SpaceDataModel._unknown_id("CDAWeb", [r["Id"]::String for r in get_cached_json(SP_ENDPOINT)], id)
    return only(rows)
end

# `metadata` is a function of `id`
Base.:(==)(a::Dataset, b::Dataset) = (a.id, a.direct, a.master_attributes) == (b.id, b.direct, b.master_attributes)
Base.hash(ds::Dataset, h::UInt) = hash((ds.id, ds.direct, ds.master_attributes), h)

function Base.show(io::IO, ds::Dataset)
    print(io, "CDAWeb.Dataset(", repr(ds.id))
    ds.direct && print(io, "; direct = true", ds.master_attributes ? ", master_attributes = true" : "")
    print(io, ")")
end

SpaceDataModel.name(ds::Dataset) = ds.id
SpaceDataModel.remotefiles(ds::Dataset, t0, t1) = _get_file_urls_from_api(ds.id, DateTime(t0), DateTime(t1))
SpaceDataModel.getdata(ds::Dataset, t0::DateTime, t1::DateTime; kw...) = _get_dataset(ds.id, t0, t1; kw...)
Base.keys(ds::Dataset) = [v.name for v in _variables(ds.id)]
Base.values(ds::Dataset) = [ds[v.name] for v in _variables(ds.id)]
Base.getindex(ds::Dataset, var::Union{AbstractString, Symbol}) = Variable(ds, String(var))

"""
    CDAWeb.Variable(dataset, name)

The variable `name` of a [`CDAWeb.Dataset`](@ref), `dataset[name]`.
"""
struct Variable <: DataSource
    dataset::Dataset
    name::String
end

Base.:(==)(a::Variable, b::Variable) = a.dataset == b.dataset && a.name == b.name
Base.hash(v::Variable, h::UInt) = hash((v.dataset, v.name), h)
Base.show(io::IO, v::Variable) = (show(io, v.dataset); print(io, "[", repr(v.name), "]"))

SpaceDataModel.name(v::Variable) = v.name

function SpaceDataModel.getmeta(v::Variable)
    path = _master_path(v.dataset.id)
    isnothing(path) && return NoMetadata()
    cdf = CommonDataFormat.CDFDataset(path)
    return v.name in keys(cdf) ? CommonDataFormat.attrib(cdf[v.name]) : NoMetadata()
end

function SpaceDataModel.getdata(v::Variable, t0::DateTime, t1::DateTime; kw...)
    ds = v.dataset
    ds.direct && return _get_data(ds.id, v.name, t0, t1; ds.master_attributes, kw...)
    data = getdata(ds, t0, t1; kw...)
    return _is_virtual(data, v.name) ? _get_data(ds.id, v.name, t0, t1; kw...) : data[v.name]
end

# CDAWeb computes virtual variables (e.g. THEMIS ESA quality-filtered spectra) on request: files hold
# only a placeholder record, which indexing by time would overrun
function _is_virtual(data, var)
    src = parent(data)
    file = src isa AbstractVector ? first(src) : src
    var in keys(file) || return false
    return uppercase(string(get(CommonDataFormat.attrib(file[var]), "VIRTUAL", ""))) == "TRUE"
end

"""
    cda"dataset"
    cda"dataset/variable"
    cda"dataset/variable1,variable2"

`CDAWeb.Dataset(dataset)`, its [`CDAWeb.Variable`](@ref), or a `Vector` of them.

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
