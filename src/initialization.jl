@static if isdefined(Base, :OncePerProcess)
    const cache_metadata_variable = Base.OncePerProcess{CACHE_METADATA_VARIABLE_TYPE}() do
        _load_cache_metadata(false)
    end
    const cache_metadata_orig = Base.OncePerProcess{CACHE_METADATA_ORIG_TYPE}() do
        _load_cache_metadata(true)
    end
    const master_cdf_index = Base.OncePerProcess{Dict{String, String}}() do
        build_master_cdf_index()
    end
else
    const _cache_metadata_variable = Ref{Union{CACHE_METADATA_VARIABLE_TYPE, Nothing}}(nothing)
    function cache_metadata_variable()
        if isnothing(_cache_metadata_variable[])
            _cache_metadata_variable[] = _load_cache_metadata(false)
        end
        return _cache_metadata_variable[]
    end
    const _cache_metadata_orig = Ref{Union{CACHE_METADATA_ORIG_TYPE, Nothing}}(nothing)
    function cache_metadata_orig()
        if isnothing(_cache_metadata_orig[])
            _cache_metadata_orig[] = _load_cache_metadata(true)
        end
        return _cache_metadata_orig[]
    end
    const _master_cdf_index = Ref{Union{Dict{String, String}, Nothing}}(nothing)
    function master_cdf_index()
        if isnothing(master_cdf_index[])
            _master_cdf_index[] = build_master_cdf_index()
        end
        return _master_cdf_index[]
    end
end

cache_metadata(orig::Bool) = orig ? cache_metadata_orig() : cache_metadata_variable()