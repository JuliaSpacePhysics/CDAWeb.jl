function download_and_extract_master_cdf(url::String)
    mkpath(MASTERS_CDF_PATH)

    return mktempdir() do tmp_path
        master_archive = joinpath(tmp_path, "masters.tar")
        Downloads.download(url, master_archive)
        Tar.extract(master_archive, MASTERS_CDF_PATH)
    end 
end

function update_master_cdf(masters_url = master_url; verbose = false)
    response = HTTP.head(masters_url)
    last_modified = get(Dict(response.headers), "Last-Modified", "")

    cache_file = joinpath(MASTERS_CDF_PATH, ".last_modified")
    stored_last_modified = isfile(cache_file) ? read(cache_file, String) : nothing
    verbose && @info "Last modified: $last_modified"
    if stored_last_modified != last_modified
        rm(MASTERS_CDF_PATH; recursive=true, force=true)
        download_and_extract_master_cdf(masters_url)
        write(cache_file, last_modified)
        return true
    end
    return false
end

function build_master_cdf_index()
    files = filter(f -> endswith(f, ".cdf"), readdir(MASTERS_CDF_PATH; join = true))
    datasets = map(files) do f
        CDFDataset(f)
    end
    names = map(datasets) do d
        attrib = d.attrib
        if haskey(attrib, "Logical_source") && length(attrib["Logical_source"]) > 0
            return attrib["Logical_source"][1] |> uppercase
        elseif haskey(attrib, "TITLE") && length(attrib["TITLE"]) > 0
            return attrib["TITLE"][1] |> uppercase
        else
            return basename(d.source.filename)
        end
    end
    return Dict(zip(names, files))
end


function find_master_cdf(name)
    if endswith(name, ".cdf")
        path = joinpath(MASTERS_CDF_PATH, name)
        isfile(path) && return CDFDataset(path)
    end
    
    # Otherwise, find files whose names contain the substring (case-insensitive)
    lcname = lowercase(name)
    files = filter!(f -> endswith(f, ".cdf") && occursin(lcname, f), readdir(MASTERS_CDF_PATH))
    if length(files) == 1
        return CDFDataset(joinpath(MASTERS_CDF_PATH, first(files)))
    elseif isempty(files)
        throw(ArgumentError("No master CDF matches $(name) in $(MASTERS_CDF_PATH)"))
    else
        throw(ArgumentError("Multiple master CDFs match $(name): $(files). Please specify more precisely."))
    end
end