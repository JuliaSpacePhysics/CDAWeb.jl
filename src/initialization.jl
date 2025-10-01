# Master CDF index still uses in-memory cache since it's read-only after initialization
@static if isdefined(Base, :OncePerProcess)
    const master_cdf_index = Base.OncePerProcess{Dict{String, String}}() do
        build_master_cdf_index()
    end
else
    const _master_cdf_index = Ref{Union{Dict{String, String}, Nothing}}(nothing)
    function master_cdf_index()
        if isnothing(_master_cdf_index[])
            _master_cdf_index[] = build_master_cdf_index()
        end
        return _master_cdf_index[]
    end
end
