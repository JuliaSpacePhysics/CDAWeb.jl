function download_and_extract_master_cdf(url::String)
    mkpath(_masters_path())

    return mktempdir() do tmp_path
        master_archive = joinpath(tmp_path, "masters.tar")
        Downloads.download(url, master_archive)
        extract(master_archive, _masters_path())
    end
end

function update_master_cdf(masters_url = master_url; verbose = false)
    response = HTTP.head(masters_url)
    last_modified = get(Dict(response.headers), "Last-Modified", "")

    cache_file = _master_last_modified()
    stored_last_modified = isfile(cache_file) ? read(cache_file, String) : nothing
    verbose && @info "Last modified: $last_modified"
    if stored_last_modified != last_modified
        rm(_masters_path(); recursive = true, force = true)
        download_and_extract_master_cdf(masters_url)
        write(cache_file, last_modified)
        return true
    end
    return false
end

function build_master_cdf_index()
    files = filter!(f -> endswith(f, ".cdf"), readdir(_masters_path()))
    regex = r"^(.+?)_\d+_v\d+\.cdf$"
    names = map(files) do f
        # Extract ID from filename (e.g., "wi_at_def_00000000_v01.cdf" -> "WI_AT_DEF")
        m = match(regex, basename(f))
        uppercase(m.captures[1])
    end
    return Dict(zip(names, files))
end

# Master CDFs whose filenames contain `name` (case-insensitive)
function _master_files(name)
    ispath(_master_last_modified()) || update_master_cdf()
    lcname = lowercase(name)
    return filter!(f -> endswith(f, ".cdf") && occursin(lcname, f), readdir(_masters_path()))
end

function _find_master_cdf(name)
    _path = endswith(name, ".cdf") ? name : "$(lowercase(name))_00000000_v01.cdf"
    ispath(_master_last_modified()) || update_master_cdf()
    path = joinpath(_masters_path(), _path)
    isfile(path) && return CDFDataset(path)

    files = _master_files(name)
    if length(files) == 1
        return CDFDataset(joinpath(_masters_path(), first(files)))
    elseif isempty(files)
        return nothing
    else
        throw(ArgumentError("Multiple master CDFs match $(name): $(files). Please specify more precisely."))
    end
end

function find_master_cdf(name)
    file = _find_master_cdf(name)
    return !isnothing(file) ? file : throw(ArgumentError("No master CDF matches $(name) in $(_masters_path())"))
end
