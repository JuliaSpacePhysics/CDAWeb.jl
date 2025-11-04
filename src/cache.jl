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
