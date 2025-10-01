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
    return [desc.Name for desc in data.FileDescription]
end

"""Fetch files from API, download them, and add to cache."""
function _fetch_and_cache_files!(t0, t1, dataset, variable; orig = false, disable_cache = false, kw...)
    args = orig ? (dataset,) : (dataset, variable)
    file_urls = _get_file_urls_from_api(args..., t0, t1; kw...)
    file_paths = _download_file.(file_urls, args...)
    disable_cache || _add_files_to_cache!(file_paths, dataset, variable, t0, t1; orig)
    return file_paths
end

"""Fetch and cache original CDF files."""
function find_cached_and_missing(dataset, start_time, stop_time; kw...)
    cache = cache_metadata(true)

    is_valids = findall(cache) do row
        row.dataset == dataset &&
            row.start_time < stop_time &&
            row.end_time >= start_time &&
            isfile(row.path)
    end
    has_full_coverage = _check_cache_coverage(cache, is_valids, start_time, stop_time)
    missing_ranges = has_full_coverage ? Tuple{DateTime, DateTime}[] : [(start_time, stop_time)]
    return cache.path[is_valids], missing_ranges
end

"""Find cached files and missing time ranges using fragment-based caching (only for orig=false)."""
function find_cached_and_missing(dataset, variable, start_time, stop_time, fragment_period::Period)
    # Split requested range into fragments
    fragments = split_into_fragments(start_time, stop_time, fragment_period)
    # Categorize fragments as cached or missing
    cache = cache_metadata(false)

    cached_files = String[]
    missings = Tuple{DateTime, DateTime}[]

    for (frag_start, frag_stop) in fragments
        matching_rows = findall(cache) do row
            row.dataset == dataset &&
                row.variable == variable &&
                row.start_time <= frag_start &&
                row.end_time >= frag_stop &&
                isfile(row.path)
        end
        if !isempty(matching_rows)
            for idx in matching_rows
                file_path = cache.path[idx]
                if file_path ∉ cached_files
                    push!(cached_files, file_path)
                end
            end
        else
            push!(missings, (frag_start, frag_stop))
        end
    end

    # Group contiguous missing fragments to minimize API calls
    # missing_ranges = group_contiguous_fragments(missing_fragments)
    return cached_files, missings
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
        sort(all_files)
    else
        sort(cached_files)
    end
end

function get_data_files(dataset, start_time, stop_time; kw...)
    return get_data_files(dataset, "", start_time, stop_time; orig = true, kw...)
end
