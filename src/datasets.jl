function find_datasets(name)
    path = joinpath(MASTERS_CDF_PATH, name)
    isfile(path) && return CDFDataset(path)

    # Otherwise, find files whose names contain the substring (case-insensitive)
    lcname = lowercase(name)
    files = filter!(f -> endswith(f, ".cdf") && occursin(lcname, f), readdir(MASTERS_CDF_PATH))
    return map(files) do f
        CDFDataset(joinpath(MASTERS_CDF_PATH, f))
    end
end