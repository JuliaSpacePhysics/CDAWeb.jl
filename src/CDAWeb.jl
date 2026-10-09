module CDAWeb

using Dates
using Downloads
using Tar: extract
using HTTP
using PrecompileTools
using CDFDatasets
import CommonDataFormat
using JSON
using SQLite, DBInterface
using Tables: columntable
using SpaceDataModel: SpaceDataModel, TimeRanges, DataSource, AbstractDataset, NoMetadata, getdata, getmeta, remotefiles, times
import CDFDatasets as CDF
using CDFDatasets: variable, cdfopen

# RESTful API wrappers
export get_datasets, get_variables, get_inventory, get_original_file_descs, get_data_file_descs
# Data access
export get_data_files
export getdata, getmeta, remotefiles, times
export clear_cache!, clear_metadata_cache!
export find_master_cdf
export @cda_str

const _METADATA_CACHE = Dict{String, Any}()
const _METADATA_LOCK = ReentrantLock()

const master_url = "https://spdf.gsfc.nasa.gov/pub/software/cdawlib/0MASTERS/master.tar"
const CDAWEB_BASE_URL = "https://cdaweb.gsfc.nasa.gov/WS/cdasr/1"
const ENDPOINT = "$(CDAWEB_BASE_URL)/dataviews"
const SP_ENDPOINT = "$(CDAWEB_BASE_URL)/dataviews/sp_phys/datasets"
const HEADER = ["Accept" => "application/json"]

_normquery(::Nothing) = nothing
_normquery(q) = [string(k) => string(v) for (k, v) in pairs(q)]

_http_get(url; query = nothing, kw...) = HTTP.get(url, HEADER, query = _normquery(query); kw...)
# Assigned in `__init__`: a `const` path would bake in the precompiling user's `homedir()`.
const BASE_PATH = Ref{String}()
_masters_path() = joinpath(BASE_PATH[], "masters")
_master_last_modified() = joinpath(_masters_path(), ".last_modified")
_data_cache_path() = joinpath(BASE_PATH[], "data")

__init__() = (BASE_PATH[] = get(ENV, "CDAWEB_DIR", joinpath(homedir(), ".cdaweb")))

include("master.jl")
include("operation.jl")
include("search.jl")
include("data.jl")
include("files.jl")
include("cache.jl")
include("database.jl")
include("datasets.jl")
include("types.jl")
include("show.jl")
include("precompile.jl")

"""Get cache metadata"""
function cache_metadata(orig::Bool = false)
    db = _get_cache_db(orig)
    cols = columntable(DBInterface.execute(db, "SELECT * FROM cache"))
    return merge(cols, (start_time = unix2datetime.(cols.start_time), end_time = unix2datetime.(cols.end_time)))
end

end
