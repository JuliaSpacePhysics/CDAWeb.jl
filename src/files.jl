_filename(url, variable) = "$(variable)_$(basename(url))"
_filename(url) = basename(url)

function _download_file(url, dataset, args...; dir = joinpath(DATA_CACHE_PATH, dataset), update = false)
    mkpath(dir)
    output = joinpath(dir, _filename(url, args...))
    if !isfile(output) || update
        @debug "Downloading $(url) to $(output)"
        Downloads.download(url, output)
    end
    return output
end

function _get_file_urls_from_api(args...; kw...)
    url = _build_request_url(args...; kw...)
    @debug "Requesting data from CDAWeb: $(url)"
    # Set headers to request JSON response
    response = HTTP.get(url, HEADER)
    check_response(response)
    # Extract file URLs from JSON response
    data = JSON3.read(response.body)
    return (desc.Name for desc in data.FileDescription)
end

"""Fetch files from API, download them, and add to cache."""
function _fetch_and_cache_files!(t0, t1, dataset, variable; orig = false, disable_cache = false, kw...)
    args = orig ? (dataset,) : (dataset, variable)
    file_urls = _get_file_urls_from_api(args..., t0, t1; kw...)
    file_paths = _download_file.(file_urls, args...)
    disable_cache || _add_files_to_cache!(file_paths, dataset, variable, t0, t1; orig)
    return file_paths
end

"""Find cached files and missing time ranges using SQL query (for orig=true)."""
function find_cached_and_missing(dataset, start_time, stop_time; kw...)
    # Check coverage and collect files
    current_time = start_time
    cached_files = String[]

    for (entry_start, entry_end, path) in _query(dataset, start_time, stop_time)
        !isfile(path) && return cached_files, [(start_time, stop_time)]
        if unix2datetime(entry_start) > current_time
            # Gap found - need to fetch missing range
            return cached_files, [(start_time, stop_time)]
        end
        push!(cached_files, path)
        current_time = max(current_time, unix2datetime(entry_end))

        if current_time >= stop_time
            # Full coverage achieved
            return cached_files, Tuple{DateTime, DateTime}[]
        end
    end

    # Gap at the end - need to fetch entire range
    return cached_files, [(start_time, stop_time)]
end

"""Find cached files and missing time ranges using fragment-based caching and SQL (for orig=false)."""
function find_cached_and_missing(dataset, variable, start_time, stop_time, fragment_period::Period)
    # Split requested range into fragments
    fragments = split_into_fragments(start_time, stop_time, fragment_period)

    entries = Tuple{DateTime, DateTime, String}[]
    for row in _query(dataset, variable, start_time, stop_time)
        push!(entries, (unix2datetime(row[1]), unix2datetime(row[2]), row[3]))
    end

    cached_files = Set{String}()
    missings = Tuple{DateTime, DateTime}[]

    # Check coverage for each fragment
    entry_idx = 1
    for (frag_start, frag_stop) in fragments
        current_time = frag_start
        fragment_covered = false

        # Find entries that overlap with this fragment
        while entry_idx <= length(entries)
            entry_start, entry_end, path = entries[entry_idx]

            # Skip entries that end before fragment starts
            if entry_end < frag_start
                entry_idx += 1 && continue
            end

            # Stop if entry starts after fragment ends
            entry_start >= frag_stop && break
            # Check for gap
            entry_start > current_time && break

            push!(cached_files, path)
            current_time = max(current_time, entry_end)
            if current_time >= frag_stop
                fragment_covered = true
                break
            end
            entry_idx += 1
        end
        !fragment_covered && push!(missings, (frag_start, frag_stop))
    end

    return collect(cached_files), missings
end

function get_data_files(dataset, variable, start_time, stop_time; disable_cache = false, orig = false, fragment_period = Hour(24), kw...)
    start_time = DateTime(start_time)
    stop_time = DateTime(stop_time)
    dataset = any(islowercase, dataset) ? uppercase(dataset) : dataset

    if disable_cache
        return _fetch_and_cache_files!(start_time, stop_time, dataset, variable; orig, disable_cache, kw...)
    end

    cached_files, missing_ranges = orig ? find_cached_and_missing(dataset, start_time, stop_time; kw...) :
        find_cached_and_missing(dataset, variable, start_time, stop_time, fragment_period)

    return if !isempty(missing_ranges)
        # Fetch missing time ranges
        all_files = mapreduce(vcat, missing_ranges; init = cached_files) do (range_start, range_stop)
            @debug "Fetching missing range: $(range_start) to $(range_stop)"
            _fetch_and_cache_files!(range_start, range_stop, dataset, variable; orig, kw...)
        end
        sort!(unique!(all_files))
    else
        sort!(unique!(cached_files))
    end
end

function get_data_files(dataset, start_time, stop_time; kw...)
    return get_data_files(dataset, "", start_time, stop_time; orig = true, kw...)
end
