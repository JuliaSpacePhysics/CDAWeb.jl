# Cache-specific utility functions (database functions are in database.jl)

"""Clear the in-memory metadata cache (datasets, variables, etc.)."""
function clear_metadata_cache!()
    empty!(_METADATA_CACHE)
    return
end

function _get(url; headers = HEADER, throw = true, query...)
    if !isempty(query)
        url = url * "?" * join(["$(k)=$(URIs.escapeuri(string(v)))" for (k, v) in pairs(query)], "&")
    end
    buf = IOBuffer()
    Downloads.request(url; method = "GET", headers, output = buf, throw)
    return take!(buf)
end

_json_read1(body::AbstractVector{UInt8}) = first(values(JSON.parse(String(body))))

function get_cached_json(url; use_cache = true, query...)
    return if use_cache
        result = get!(_METADATA_CACHE, url) do
            _json_read1(_get(url))
        end
        _filter_metadata(result, query)
    else
        _json_read1(_get(url; query...))
    end
end

# Filter a cached metadata array by matching query params to struct fields.
# Param names are camelCase (e.g. observatoryGroup); field names are PascalCase (ObservatoryGroup).
# Array fields use membership testing; scalar fields use equality.
function _filter_metadata(items, filters)
    _camelCase(s) = Symbol(uppercasefirst(String(s)))
    isempty(filters) && return items
    normalized_filters = Dict(_camelCase(k) => v for (k, v) in filters)
    return filter(items) do item
        all(normalized_filters) do (k, v)
            val = item[String(k)]
            val isa AbstractArray ? (v in val) : (val == v)
        end
    end
end

"""Clear cache entries for a specific dataset (process-safe)."""
function clear_cache!(dataset)
    for orig in (false, true)
        db = _get_cache_db(orig)
        DBInterface.execute(db, "DELETE FROM cache WHERE dataset = ?", [dataset])
    end
    return
end

"""Clear all cache entries."""
function clear_cache!()
    for orig in (false, true)
        db = _get_cache_db(orig)
        DBInterface.execute(db, "DELETE FROM cache")
    end
    return
end

# Get the time range of the file.
@inline function _get_file_time_range(file, variable)
    dataset = CDFDataset(file)
    var = dataset[variable]
    time_var = CDFDatasets.attrib(var, "DEPEND_0")
    isnothing(time_var) && return nothing
    times = dataset[time_var]
    return isempty(times) ? nothing : (DateTime(times[1]), DateTime(times[end]))
end

# Select time variable(s) from the file and return the extrema of the time variable(s).
@inline function _get_file_time_range(file)
    dataset = CDFDataset(file)
    t0 = typemax(DateTime)
    t1 = typemin(DateTime)
    for (key, var) in dataset
        isempty(var) && continue
        eltype(var) <: Dates.AbstractDateTime || continue
        t0 = min(t0, DateTime(var[1]))
        t1 = max(t1, DateTime(var[end]))
    end
    return t0 > t1 ? nothing : (t0, t1)  # Return nothing if no DateTime found
end

# interval with a left closed and right open endpoint
function _expand_time_ranges(timeranges, requested_start, requested_stop)
    start_times = first.(timeranges)
    end_times = last.(timeranges)
    @assert issorted(start_times) && issorted(end_times)
    start_times[1] = min(requested_start, start_times[1])
    # expand the end time to the next file's start time if it is later
    N = length(timeranges)
    for i in 1:(N - 1)
        end_times[i] = max(end_times[i], start_times[i + 1])
    end
    end_times[end] = max(requested_stop, end_times[end])
    return start_times, end_times
end

function _add_files_to_cache!(requested_start, requested_stop, files, dataset, args...)
    timeranges = _get_file_time_range.(files, args...)
    if any(isnothing, timeranges)
        @debug "Could not determine time range for $files, skipping cache metadata update"
        return
    end

    start_times, end_times = _expand_time_ranges(timeranges, requested_start, requested_stop)
    _update_cache!(dataset, args..., start_times, end_times, files)
    return
end

# Fragment-based caching utilities

# Split time range into fixed-duration fragments with aligned boundaries.
# Align boundaries to fragment intervals for consistent caching
function split_into_fragments(t0, t1, Δt)
    return TimeRanges(floor(t0, Δt), ceil(t1, Δt), Δt)
end

"""Group contiguous fragments to minimize API calls."""
function group_contiguous_fragments(fragments::Vector{Tuple{DateTime, DateTime}})
    isempty(fragments) && return Tuple{DateTime, DateTime}[]
    grouped = Tuple{DateTime, DateTime}[]
    current_start, current_stop = fragments[1]

    for i in 2:length(fragments)
        frag_start, frag_stop = fragments[i]
        if frag_start == current_stop
            # Contiguous, extend current range
            current_stop = frag_stop
        else
            # Gap found, save current range and start new one
            push!(grouped, (current_start, current_stop))
            current_start, current_stop = frag_start, frag_stop
        end
    end
    # Add the last range
    push!(grouped, (current_start, current_stop))
    return grouped
end
