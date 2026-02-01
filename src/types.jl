"""
    CDAWebProduct{P} <: Function

A lazy specification for retrieving CDAWeb data. When called, it fetches data using
`get_data` with `clip=true` and `direct=false` by default for better performance.

See also: [`CDAWebProducts`](@ref), [`@cda_str`](@ref)
"""
struct CDAWebProduct{P} <: Function
    path::P
end

"""
    CDAWebProducts{T} <: AbstractVector{T}

A vector-like container of `CDAWebProduct`s that is also callable.

See also: [`CDAWebProduct`](@ref), [`@cda_str`](@ref)
"""
struct CDAWebProducts{T} <: AbstractVector{T}
    paths::Vector{T}
end

function _CDAWebProducts(dataset, params)
    prods = map(params) do p
        CDAWebProduct("$dataset/$p")
    end
    return CDAWebProducts(prods)
end

Base.size(p::CDAWebProducts) = size(p.paths)
Base.getindex(p::CDAWebProducts, i) = getindex(p.paths, i)

(p::CDAWebProduct)(args...; kw...) = get_data(p.path, args...; clip = true, direct = false, kw...)
(ps::CDAWebProducts)(args...; kw...) = map(ps.paths) do p
    p(args...; kw...)
end

"""
    cda"dataset/parameter"
    cda"dataset/parameter1,parameter2"

String macro to create a CDAWebProduct from a string identifier.
Supports multiple parameters separated by commas, which returns a CDAWebProducts object (like a vector of CDAWebProduct).

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
