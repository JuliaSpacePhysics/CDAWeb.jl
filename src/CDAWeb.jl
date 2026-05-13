module CDAWeb

using Dates
using Downloads
using Tar: extract
using HTTP
using CDFDatasets
using JSON
using SQLite, DBInterface
using Tables: columntable
using SpaceDataModel: TimeRanges
import CDFDatasets as CDF
using CDFDatasets: var_type, variable, cdfopen

# RESTful API wrappers
export get_dataviews, get_datasets, get_instruments, get_instrument_types
export get_observatories, get_observatory_groups, get_observatory_groups_and_instruments
export get_inventory, get_variables, get_original_file_descs, get_data_file_descs
# Data access
export get_data, get_dataset, get_data_files
export clear_cache!, clear_metadata_cache!
export find_master_cdf
export find_datasets
export @cda_str, CDAWebProduct, CDAWebProducts

const _METADATA_CACHE = Dict{String, Any}()

const master_url = "https://spdf.gsfc.nasa.gov/pub/software/cdawlib/0MASTERS/master.tar"
const CDAWEB_BASE_URL = "https://cdaweb.gsfc.nasa.gov/WS/cdasr/1"
const ENDPOINT = "$(CDAWEB_BASE_URL)/dataviews"
const SP_ENDPOINT = "$(CDAWEB_BASE_URL)/dataviews/sp_phys/datasets"
const HEADER = ["Accept" => "application/json"]
const BASE_PATH = joinpath(homedir(), ".cdaweb")
const MASTERS_CDF_PATH = joinpath(BASE_PATH, "masters")
const MASTER_LAST_MODIFIED = joinpath(MASTERS_CDF_PATH, ".last_modified")
const DATA_CACHE_PATH = joinpath(BASE_PATH, "data")

include("master.jl")
include("operation.jl")
include("data.jl")
include("files.jl")
include("cache.jl")
include("database.jl")
include("datasets.jl")
include("initialization.jl")
include("precompile.jl")
include("types.jl")

"""Get cache metadata"""
function cache_metadata(orig::Bool = false)
    db = _get_cache_db(orig)
    cols = columntable(DBInterface.execute(db, "SELECT * FROM cache"))
    return merge(cols, (start_time = unix2datetime.(cols.start_time), end_time = unix2datetime.(cols.end_time)))
end

end
