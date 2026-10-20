# Cache-specific utility functions (database functions are in database.jl)

"""Clear the metadata cache (datasets, variables, etc.), in memory and on disk."""
function clear_metadata_cache!()
    lock(() -> empty!(_METADATA_CACHE), _METADATA_LOCK)
    rm(_metadata_dir(); recursive = true, force = true)
    return
end

# Every CDAS response is `{"Wrapper": [record, ...]}`
_json_read1(resp) = _json_read1(resp.body)
_json_read1(body::AbstractVector{UInt8}) = Vector{JSON.Object{String, Any}}(first(values(JSON.parse(String(body)))))

_metadata_dir() = joinpath(BASE_PATH[], "metadata")

# Persisted for a day, so cached data stays reachable offline
function _fetch_json(url)
    path = joinpath(_metadata_dir(), replace(url, r"[^[:alnum:]]+" => "_") * ".json")
    isfile(path) && time() - mtime(path) < 86400 && return _json_read1(read(path))
    resp = try
        _http_get(url)
    catch e
        isfile(path) || rethrow()
        @warn "Using the metadata cached at $path" exception = e
        return _json_read1(read(path))
    end
    mkpath(dirname(path))
    tmp = tempname(dirname(path))
    write(tmp, resp.body)
    mv(tmp, path; force = true)
    return _json_read1(resp)
end

function get_cached_json(url; use_cache = true, query...)
    return if use_cache
        # Fetched outside the lock so one slow request doesn't block other lookups;
        # concurrent misses may fetch twice, and the first stored result wins
        result = lock(() -> get(_METADATA_CACHE, url, nothing), _METADATA_LOCK)
        if isnothing(result)
            fetched = _fetch_json(url)
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
    matchers = [_matcher(k, v) for (k, v) in pairs(filters)]
    return filter(item -> all(m -> m(item), matchers), items)
end

_matcher(k, v) = k == :id ?
    item -> any(f -> isequal(get(item, f, nothing), v), ("Id", "Doi", "SpaseResourceId")) :
    _field_matcher(uppercasefirst(String(k)), v)
_field_matcher(field, v) = item -> (val = item[field]; val isa AbstractArray ? v in val : val == v)

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

function _add_files_to_cache!(requested_start, requested_stop, timeranges, files, dataset, args...)
    start_times, end_times = _expand_time_ranges(timeranges, requested_start, requested_stop)
    _update_cache!(start_times, end_times, files, dataset, args...)
    return
end
