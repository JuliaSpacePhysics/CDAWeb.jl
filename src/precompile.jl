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
                # A bare row: `Dataset(id)` would fetch the dataset list
                row = JSON.Object{String, Any}("Id" => dataset)
                Dataset(row)[var](t0, t1)[:]
                Dataset(row; direct=true)[var](t0, t1)[:]
                # Searching and showing results, over a stand-in dataset list
                _METADATA_CACHE[SP_ENDPOINT] = [JSON.Object{String, Any}(
                    "Id" => dataset, "Label" => "OMNI merged hourly magnetic field, plasma",
                    "ObservatoryGroup" => Any["OMNI (Combined 1AU IP Data; Magnetic and Solar Indices)"],
                    "TimeInterval" => JSON.Object{String, Any}("Start" => "2020-01-01T00:00:00.000Z", "End" => "2020-01-02T00:00:00.000Z"))]
                show(IOContext(devnull, :limit => true), MIME"text/plain"(), get_datasets("OMNI", r"hourly"i))
            finally
                clear_metadata_cache!()
                _SEARCH_TEXTS[] = nothing
                # Open SQLite handles must not be serialized into the pkgimage
                _close_cache_db!()
            end
        end
    end
end
