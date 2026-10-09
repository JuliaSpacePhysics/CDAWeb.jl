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
        lock(() -> empty!(_VARIABLES), _METADATA_LOCK)
        return true
    end
    return false
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

# master.tar lags the directory it is built from: masters of datasets added since are only there one by one
function _master_path(id)
    file = "$(lowercase(id))_00000000_v01.cdf"
    path = joinpath(_masters_path(), file)
    isfile(path) && return path
    resp = try
        HTTP.get("$(dirname(master_url))/$file")
    catch e
        e isa HTTP.StatusError && e.status == 404 && return nothing
        rethrow()
    end
    mkpath(_masters_path())
    tmp = tempname(_masters_path())
    write(tmp, resp.body)
    mv(tmp, path; force = true)
    return path
end

# Data variables of a dataset, from its master CDF, which may list variables its data files lack or
# miss some they have. Read from the raw CDF (about 0.5 ms): CDFDatasets' variables decode data on access.
const _VarInfo = @NamedTuple{name::String, description::String}
const _VARIABLES = Dict{String, Vector{_VarInfo}}()

function _variables(id)
    vars = lock(() -> get(_VARIABLES, id, nothing), _METADATA_LOCK)
    isnothing(vars) || return vars
    path = _master_path(id)
    vars = isnothing(path) ? _VarInfo[] : _data_variables(path)
    lock(() -> _VARIABLES[id] = vars, _METADATA_LOCK)
    return vars
end

function _data_variables(path)
    cdf = CommonDataFormat.CDFDataset(path)
    out = _VarInfo[]
    for name in keys(cdf)
        a = CommonDataFormat.attrib(cdf[name])
        get(a, "VAR_TYPE", "") == "data" || continue
        push!(out, (; name = String(name), description = _squeeze(string(get(a, "CATDESC", "")))))
    end
    return out
end

_squeeze(s) = replace(strip(s), r"\s+" => " ")
