module CDAWeb

using Dates
using Downloads
using Tar
using HTTP
using CDFDatasets
using JSON3
using SQLite, DBInterface
using TypedTables: FlexTable
using ResumableFunctions
import CDFDatasets as CDF
using CDFDatasets: ConcatCDFVariable, ConcatCDFDataset, var_type

export get_data, get_data_files
export get_dataset, get_datasets, get_variables
export clear_cache!
export find_master_cdf
export find_datasets

const master_url = "https://spdf.gsfc.nasa.gov/pub/software/cdawlib/0MASTERS/master.tar"
const BASE_PATH = joinpath(homedir(), ".cdaweb")
const MASTERS_CDF_PATH = joinpath(BASE_PATH, "masters")
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

"""Get cache metadata"""
function cache_metadata(orig::Bool=false)
    db = _get_cache_db(orig)
    query_result = DBInterface.execute(db, "SELECT * FROM cache")
    tbl = FlexTable(query_result)
    tbl.start_time = unix2datetime.(tbl.start_time)
    tbl.end_time = unix2datetime.(tbl.end_time)
    return tbl
end

end
