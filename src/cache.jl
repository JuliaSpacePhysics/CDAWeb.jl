function _empty_table_variable()
    return TypedTables.Table(
        dataset = String31[],
        variable = String31[],
        start_time = DateTime[],
        end_time = DateTime[],
        path = String[]
    )
end

function _empty_table_orig()
    return TypedTables.Table(
        dataset = String31[],
        start_time = DateTime[],
        end_time = DateTime[],
        path = String[]
    )
end

_get_cache_metadata_file(orig::Bool) = joinpath(DATA_CACHE_PATH, "cache_metadata_$(orig ? "orig" : "variable").arrow")

function _load_cache_metadata(orig::Bool)
    metadata_file = _get_cache_metadata_file(orig)
    return if isfile(metadata_file)
        arrow_table = Arrow.Table(metadata_file)
        copy(TypedTables.Table(arrow_table))
    else
        orig ? _empty_table_orig() : _empty_table_variable()
    end
end

function _persist_cache_metadata(orig::Bool)
    !is_cache_dirty(orig) && return
    mkpath(DATA_CACHE_PATH)
    file = _get_cache_metadata_file(orig)
    return try
        Arrow.write(file, cache_metadata(orig))
        reset_cache_dirty!(orig)
    catch e
        @warn "Failed to persist variable cache metadata: $e"
    end
end

# Public API for manual cache management
function clear_cache!(dataset)
    # Clear from variable cache
    cache_var = cache_metadata(false)
    rows_to_remove_var = cache_var.dataset .== dataset
    if any(rows_to_remove_var)
        indices_to_remove = findall(rows_to_remove_var)
        deleteat!(cache_var, indices_to_remove)
        CACHE_DIRTY_VARIABLE[] = true
    end
    # Clear from orig cache
    cache_orig = cache_metadata(true)
    rows_to_remove_orig = cache_orig.dataset .== dataset
    if any(rows_to_remove_orig)
        indices_to_remove = findall(rows_to_remove_orig)
        deleteat!(cache_orig, indices_to_remove)
        CACHE_DIRTY_ORIG[] = true
    end
    return persist_cache!()
end

function clear_cache!()
    for orig in (false, true)
        empty!(cache_metadata(orig))
        metadata_file = _get_cache_metadata_file(orig)
        isfile(metadata_file) && rm(metadata_file)
    end
    CACHE_DIRTY_VARIABLE[] = false
    CACHE_DIRTY_ORIG[] = false
    return
end

function persist_cache!()
    _persist_cache_metadata(false)
    _persist_cache_metadata(true)
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

function _check_cache_coverage(cache, is_valids, start_time::DateTime, stop_time::DateTime)
    if length(is_valids) == 0
        return false
    end

    # Check if we have complete coverage
    current_time = start_time
    for idx in is_valids
        row = cache[idx]
        entry_start = row.start_time
        entry_end = row.end_time
        if entry_start > current_time
            # Gap before this file
            return false
        end
        current_time = max(current_time, entry_end)
        if current_time >= stop_time
            break
        end
    end

    # Check if there's a gap at the end
    if current_time < stop_time
        return false
    end
    return true
end

function update_cache_metadata!(orig, dataset, variable, start_times, end_times, files)
    cache = cache_metadata(orig)
    # Find existing entries to update
    existing_indices = if orig
        # For orig cache, match by dataset only
        findall(cache) do row
            row.dataset == dataset &&
                any(eachindex(start_times, end_times)) do i
                row.start_time >= start_times[i] && row.end_time <= end_times[i]
            end
        end
    else
        findall(cache) do row
            row.dataset == dataset && row.variable == variable &&
                any(eachindex(start_times, end_times)) do i
                row.start_time >= start_times[i] && row.end_time <= end_times[i]
            end
        end
    end

    # Remove existing entries - we'll replace them with merged data
    !isempty(existing_indices) && deleteat!(cache, existing_indices)

    # Create new entries
    new_row = if orig
        TypedTables.Table(
            dataset = fill(String31(dataset), length(files)),
            start_time = start_times,
            end_time = end_times,
            path = files,
        )
    else
        TypedTables.Table(
            dataset = fill(String31(dataset), length(files)),
            variable = fill(String31(variable), length(files)),
            start_time = start_times,
            end_time = end_times,
            path = files,
        )
    end

    append!(cache, new_row)
    set_cache_dirty!(orig)
    return cache
end


function _add_files_to_cache!(files, dataset, variable, requested_start::DateTime, requested_stop::DateTime; orig = false)
    # Get time range from file
    timeranges = _get_file_time_range.(files, variable)

    if any(isnothing, timeranges)
        @debug "Could not determine time range for $files, skipping cache metadata update"
        return
    end

    # interval with a left closed and right open endpoint
    start_times = first.(timeranges)
    end_times = last.(timeranges)
    @assert issorted(start_times) && issorted(end_times)
    start_times[1] = min(requested_start, start_times[1])
    end_times[1:(end - 1)] = start_times[2:end]
    end_times[end] = max(requested_stop, end_times[end])

    update_cache_metadata!(orig, dataset, variable, start_times, end_times, files)
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


const CACHE_METADATA_VARIABLE_TYPE = Base.return_types(_empty_table_variable, ())[1]
const CACHE_METADATA_ORIG_TYPE = Base.return_types(_empty_table_orig, ())[1]
