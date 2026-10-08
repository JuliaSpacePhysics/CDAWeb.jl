# Offline: seeds a throwaway cache with a bundled CDAWeb file so the cached read path compiles
# without network.
PrecompileTools.@setup_workload begin
    file = joinpath(@__DIR__, "..", "data", "V_omni_coho1hrs_merged_mag_plasma_20200101000000_20200102000000_cdaweb.cdf")
    dataset, var = "OMNI_COHO1HR_MERGED_MAG_PLASMA", "V"
    t0, t1 = DateTime(2020, 1, 1), DateTime(2020, 1, 2)

    PrecompileTools.@compile_workload begin
        mktempdir() do dir
            BASE_PATH[] = dir
            try
                _add_files_to_cache!(t0, t1, [file], dataset)
                _add_files_to_cache!(t0, t1, [file], dataset, var)
                # A cache miss would fall through to the network
                isempty(last(find_cached_and_missing(dataset, t0, t1))) &&
                    isempty(last(find_cached_and_missing(dataset, var, t0, t1))) ||
                    error("precompile workload cache miss")
                Dataset(dataset)[var](t0, t1)[:]
                Dataset(dataset; direct=true)[var](t0, t1)[:]
            finally
                # Open SQLite handles must not be serialized into the pkgimage
                _close_cache_db!()
            end
        end
    end
end
