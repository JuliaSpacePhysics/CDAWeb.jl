# Cache-specific utility functions (database functions are in database.jl)

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

@inline function _get_file_time_range(file, variable)
    dataset = CDFDataset(file)
    var = dataset[variable]
    time_var = CDFDatasets.attrib(var, "DEPEND_0")
    isnothing(time_var) && return nothing
    times = dataset[time_var]
    return isempty(times) ? nothing : (DateTime(times[1]), DateTime(times[end]))
end

function _add_files_to_cache!(files, dataset, variable, requested_start::DateTime, requested_stop::DateTime; orig = false)
    # Get time range from file
    timeranges = _get_file_time_range.(files, variable)

    if any(isnothing, timeranges)
        @debug "Could not determine time range for $files, skipping cache metadata update"
        return
    end

    # interval with a left closed and right open endpoint
    start_times = DateTime.(first.(timeranges))
    end_times = DateTime.(last.(timeranges))
    @assert issorted(start_times) && issorted(end_times)
    start_times[1] = min(requested_start, start_times[1])
    end_times[1:(end - 1)] = start_times[2:end]
    end_times[end] = max(requested_stop, end_times[end])

    orig ? _update_orig_cache!(dataset, start_times, end_times, files) :
    _update_variable_cache!(dataset, variable, start_times, end_times, files)
    return
end

# Fragment-based caching utilities

"""Split time range into fixed-duration fragments with aligned boundaries."""
@resumable function split_into_fragments(start_time::DateTime, stop_time::DateTime, fragment_period::Period)
    # Align boundaries to fragment intervals for consistent caching
    aligned_start = floor(start_time, fragment_period)
    aligned_stop = ceil(stop_time, fragment_period)
    current = aligned_start
    while current < aligned_stop
        fragment_end = current + fragment_period
        @yield (current, fragment_end)
        current = fragment_end
    end
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
