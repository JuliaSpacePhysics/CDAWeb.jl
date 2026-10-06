# Cache-specific utility functions (database functions are in database.jl)

"""Clear the in-memory metadata cache (datasets, variables, etc.)."""
function clear_metadata_cache!()
    lock(() -> empty!(_METADATA_CACHE), _METADATA_LOCK)
    return
end

# Read the first value from a JSON response
_json_read1(resp) = first(values(JSON.parse(String(resp.body))))

function get_cached_json(url; use_cache = true, query...)
    return if use_cache
        # Fetched outside the lock so one slow request doesn't block other lookups;
        # concurrent misses may fetch twice, and the first stored result wins
        result = lock(() -> get(_METADATA_CACHE, url, nothing), _METADATA_LOCK)
        if isnothing(result)
            fetched = _json_read1(_http_get(url))
            result = lock(() -> get!(_METADATA_CACHE, url, fetched), _METADATA_LOCK)
        end
        _filter_metadata(result, query)
    else
        _json_read1(_http_get(url; query))
    end
end

# Filter a cached metadata array by matching query params to struct fields.
# Param names are camelCase (e.g. observatoryGroup); field names are PascalCase (ObservatoryGroup).
# Array fields use membership testing; scalar fields use equality.
# `id` may be a CDAS, DOI or SPASE identifier, as the server accepts.
function _filter_metadata(items, filters)
    isempty(filters) && return items
    return filter(items) do item
        all(filters) do (k, v)
            k == :id && return v in (item["Id"], get(item, "Doi", nothing), get(item, "SpaseResourceId", nothing))
            val = item[uppercasefirst(String(k))]
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

# Select time variable(s) from the file and return the extrema of the time variable(s).
@inline function _get_file_time_range(file)
    dataset = CDFDataset(file)
    t0 = typemax(DateTime)
    t1 = typemin(DateTime)
    for (_, var) in dataset
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
    timeranges = _get_file_time_range.(files)
    if any(isnothing, timeranges)
        @debug "Could not determine time range for $files, skipping cache metadata update"
        return
    end

    start_times, end_times = _expand_time_ranges(timeranges, requested_start, requested_stop)
    _update_cache!(start_times, end_times, files, dataset, args...)
    return
end

# Fragment-based caching utilities

"""Group contiguous fragments to minimize API calls."""
function group_contiguous_fragments(fragments)
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
