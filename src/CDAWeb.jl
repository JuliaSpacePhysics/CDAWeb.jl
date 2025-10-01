module CDAWeb

using Dates
using Downloads
using Tar
using HTTP
using CDFDatasets
using JSON3
using Arrow, TypedTables
using InlineStrings: String31
using ResumableFunctions
import CDFDatasets as CDF

export get_data, get_data_files
export clear_cache!, persist_cache!
export find_master_cdf
export find_datasets

const master_url = "https://spdf.gsfc.nasa.gov/pub/software/cdawlib/0MASTERS/master.tar"
const MASTERS_CDF_PATH = joinpath(homedir(), ".cdaweb", "masters")
const DATA_CACHE_PATH = joinpath(homedir(), ".cdaweb", "data")

include("master.jl")
include("data.jl")
include("files.jl")
include("cache.jl")
include("datasets.jl")
include("initialization.jl")
include("precompile.jl")

# Global in-memory caches
const CACHE_DIRTY_VARIABLE = Ref{Bool}(false)  # Track if variable cache needs persistence
const CACHE_DIRTY_ORIG = Ref{Bool}(false)  # Track if orig cache needs persistence

is_cache_dirty(orig::Bool) = orig ? CACHE_DIRTY_ORIG[] : CACHE_DIRTY_VARIABLE[]
reset_cache_dirty!(orig::Bool) = orig ? (CACHE_DIRTY_ORIG[] = false) : (CACHE_DIRTY_VARIABLE[] = false)
set_cache_dirty!(orig::Bool) = orig ? (CACHE_DIRTY_ORIG[] = true) : (CACHE_DIRTY_VARIABLE[] = true)

# Auto-persist cache on Julia exit
function __init__()
    atexit(persist_cache!)
end

end
