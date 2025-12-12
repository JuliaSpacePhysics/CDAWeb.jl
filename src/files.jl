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

function no_data_available(data)
    return if haskey(data, :Error)
        data.Error[1] == "No data available."
    else
        isempty(data)
    end
end

function _build_request_url(dataset, variable, start_time, stop_time; format = "cdf")
    start_str = _format_time(start_time)
    stop_str = _format_time(stop_time)
    return "$(SP_ENDPOINT)/$(dataset)/data/$(start_str),$(stop_str)/$(variable)?format=$(format)"
end

function _build_request_url(dataset, start_time, stop_time)
    start_str = _format_time(start_time)
    stop_str = _format_time(stop_time)
    return "$(SP_ENDPOINT)/$(dataset)/orig_data/$(start_str),$(stop_str)/"
end


function _get_file_urls_from_api(args...; status_exception = false, kw...)
    url = _build_request_url(args...; kw...)
    @debug "Requesting data from CDAWeb: $(url)"
    # Set headers to request JSON response
    response = HTTP.get(url, HEADER; status_exception)
    data = JSON3.read(response.body)
    return if haskey(data, :FileDescription)
        (desc.Name for desc in data.FileDescription)
    elseif no_data_available(data)
        String[]
    else
        # try again and set status_exception to true to throw an error
        _get_file_urls_from_api(args...; status_exception = true, kw...)
    end
end

"""Fetch files from API, download them, and add to cache."""
function _fetch_and_cache_files!(t0, t1, args...; disable_cache = false, kw...)
    file_urls = _get_file_urls_from_api(args..., t0, t1; kw...)
    file_paths = _download_file.(file_urls, args...)
    disable_cache || !isempty(file_paths) && _add_files_to_cache!(t0, t1, file_paths, args...)
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
function find_cached_and_missing(dataset, variable, start_time, stop_time; fragment_period::Period = Hour(24))
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

"""
    get_data_files(dataset, t0, t1; kw...)

Get original data file paths for a dataset within time range (t0, t1). 

If files are not available in cache, they will be fetched and cached.
"""
get_data_files(dataset, t0, t1; kw...) = _get_data_files(t0, t1, dataset; kw...)

"""
    get_data_files(dataset, variables, t0, t1; fragment_period = Hour(24), kw...)

Get processed data file paths for a dataset + variables within time range (t0, t1). 

Note: usually this is slower and not suitable when needing multiple variables due to CDAWeb's web service processing overhead.
"""
function get_data_files(dataset, variables, t0, t1; fragment_period = Hour(24), kw...)
    return _get_data_files(t0, t1, dataset, variables; find_options = (; fragment_period), kw...)
end

function _get_data_files(start_time, stop_time, dataset, args...; disable_cache = false, find_options = (;), kw...)
    dataset = any(islowercase, dataset) ? uppercase(dataset) : dataset
    if disable_cache
        return _fetch_and_cache_files!(start_time, stop_time, dataset, args...; disable_cache, kw...)
    end
    cached_files, missing_ranges = find_cached_and_missing(dataset, args..., start_time, stop_time; find_options...)

    return if !isempty(missing_ranges)
        # Fetch missing time ranges
        all_files = mapreduce(vcat, missing_ranges; init = cached_files) do (range_start, range_stop)
            @debug "Fetching missing range: $(range_start) to $(range_stop)"
            _fetch_and_cache_files!(range_start, range_stop, dataset, args...; kw...)
        end
        sort!(unique!(all_files))
    else
        sort!(unique!(cached_files))
    end
end
