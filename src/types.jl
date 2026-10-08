"""
    CDAWeb.Dataset(id; direct = false, master_attributes = false)

The CDAWeb dataset `id`; `ds[var]` is its variable.

`direct` fetches a variable through CDAWeb's subsetting service rather than indexing the whole
cached dataset; `master_attributes` (direct only) takes its attributes from the master CDF.
"""
struct Dataset <: AbstractDataset
    id::String
    direct::Bool
    master_attributes::Bool
end

Dataset(id; direct=false, master_attributes=false) = Dataset(String(id), direct, master_attributes)

SpaceDataModel.name(ds::Dataset) = ds.id
SpaceDataModel.getdata(ds::Dataset, t0, t1; kw...) = get_dataset(ds.id, t0, t1; clip=true, kw...)

function SpaceDataModel.getdata(p::Product{Dataset}, t0, t1; kw...)
    ds = parent(p)
    return ds.direct ? _get_data(ds.id, p.variable, t0, t1; clip=true, ds.master_attributes, kw...) :
           getdata(ds, t0, t1; kw...)[p.variable]
end

function CDAWebProduct(path::AbstractString; kw...)
    id, var = _split_path(path)
    ds = Dataset(id; kw...)
    return isnothing(var) ? ds : ds[var]
end

"""
    CDAWebProducts{T} <: AbstractVector{T}

A callable vector of [`CDAWebProduct`](@ref)s.
"""
struct CDAWebProducts{T} <: AbstractVector{T}
    products::Vector{T}
end

_CDAWebProducts(dataset, params) = CDAWebProducts([CDAWebProduct("$dataset/$p") for p in params])

Base.size(p::CDAWebProducts) = size(p.products)
Base.getindex(p::CDAWebProducts, i) = getindex(p.products, i)
Base.summary(io::IO, ps::CDAWebProducts) = print(io, length(ps), "-element CDAWebProducts")

(ps::CDAWebProducts)(args...; kw...) = map(p -> p(args...; kw...), ps.products)

"""
    cda"dataset/parameter"
    cda"dataset/parameter1,parameter2"

[`CDAWebProduct`](@ref) from a string identifier; comma-separated parameters give [`CDAWebProducts`](@ref).

# Examples
```julia
# Single parameter
product = cda"OMNI_COHO1HR_MERGED_MAG_PLASMA/flow_speed"
product(t0 , t1)

# Multiple parameters
products = cda"OMNI_COHO1HR_MERGED_MAG_PLASMA/flow_speed,Pressure"
products(t0 , t1)
```
"""
macro cda_str(s)
    if contains(s, ",")
        # Multiple parameters case
        parts = split(s, "/")
        if length(parts) < 2
            error("Invalid format. Expected 'dataset/parameter1,parameter2'")
        end
        dataset = join(parts[1:(end - 1)], "/")
        params = strip.(split(parts[end], ","))
        return :(_CDAWebProducts($dataset, $params))
    else
        # Single parameter case
        return :(CDAWebProduct($s))
    end
end
