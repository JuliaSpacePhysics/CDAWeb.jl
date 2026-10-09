"""
    get_datasets(terms...)

[`CDAWeb.Dataset`](@ref)s every term matches. Matching and order in the README (Discovery).
"""
function get_datasets(terms...)
    ts = _terms(terms)
    texts, hits = _dataset_hits(ts)
    isempty(hits) && _no_match_hint("dataset", _term_counts(texts, ts))
    return Dataset.(hits)
end

"""
    get_variables(terms...; dataset = "")

[`CDAWeb.Variable`](@ref)s whose name or description every term matches, of the datasets the `dataset`
terms match. Matching rules in the README (Discovery).
"""
function get_variables(terms...; dataset = "")
    ts, dts = _terms(terms), _terms(dataset isa AbstractVector ? dataset : (dataset,))
    texts, hits = _dataset_hits(dts)
    # A master each is quicker than the whole archive for a few datasets
    length(hits) > 20 && _ensure_masters()
    vars = [_variables(row["Id"]::String) for row in hits]
    result = [ds[v.name] for (ds, vs) in zip(Dataset.(hits), vars) for v in vs if _matches(ts, v)]
    if isempty(result)
        counts = ["dataset " * c for c in _term_counts(texts, dts)]
        append!(counts, ["$(repr(w)): $(count(vs -> any(v -> _matches((w => p,), v), vs), vars))" for (w, p) in ts])
        _no_match_hint("variable", counts)
    end
    return result
end

# Mission names can be common words ("Wind" in every "solar wind" label), so datasets whose mission or
# spacecraft match more terms come first, then those of fewer missions (OMNI merges several), then those
# whose id or instrument match more
function _dataset_hits(ts)
    rows = get_cached_json(SP_ENDPOINT)
    texts, missions, keys = _search_texts(rows)
    hits = [i for i in eachindex(rows, texts) if _matches(ts, texts[i])]
    nmatch(x) = count(t -> occursin(last(t), x), ts)
    sort!(hits; by = i -> (-nmatch(missions[i]), length(get(rows[i], "ObservatoryGroup", ())), -nmatch(keys[i]), rows[i]["Id"]))
    return texts, rows[hits]
end

# Each word of a string term matches on its own, as agents phrase terms like search-box queries
_terms(terms) = [w => _term_regex(w) for t in terms for w in (t isa Regex ? (t,) : split(t))]
_matches(ts, text) = all(t -> occursin(last(t), text), ts)
# A term cannot match across the name and description, as across fields of a dataset
_matches(ts, v::_VarInfo) = all(t -> occursin(last(t), v.name) || occursin(last(t), v.description), ts)

function _ensure_masters()
    ispath(_master_last_modified()) && return
    @info "Downloading CDAWeb master CDFs (560 MB) for variable search"
    update_master_cdf()
end

_term_regex(r::Regex) = r
# A word matches whole words: it may not run on into a lowercase letter, so "MAG" skips "magnetometer" yet
# "MMS" finds `MMS1`; a plural -s/-es is allowed and a trailing `*` makes a prefix. Separator runs inside a
# word match each other ("SYM-H" finds `SYM_H`); the pieces of the split are alphanumeric, so need no escaping.
function _term_regex(s::AbstractString)
    words = join(split(rstrip(s, '*'), r"[^[:alnum:]]+"), "[^[:alnum:]\\n]+")
    tail = endswith(s, '*') ? "" : "(?:e?s)?(?!(?-i:[a-z]))"
    return Regex("(?<![[:alnum:]])" * words * tail, "i")
end

# Without it an agent cannot tell which term to drop. Variable terms count among the datasets searched.
_term_counts(texts, ts) = ["$(repr(w)): $(count(x -> occursin(p, x), texts))" for (w, p) in ts]

function _no_match_hint(noun, counts)
    length(counts) > 1 && @info "No CDAWeb $noun matches all terms; datasets each matches alone: $(join(counts, ", "))"
    return
end

# The searched fields of each dataset joined by newlines, then its mission fields, then id and instrument,
# rebuilt with the cached list: a term is then one `occursin` per dataset rather than one per field, the
# array fields parsing as `Vector{Any}`.
# A term cannot match across fields: a string term matches no newline and `.` does not match one.
const _SEARCH_TEXTS = Ref{Any}(nothing)

function _search_texts(rows)
    cached = lock(() -> _SEARCH_TEXTS[], _METADATA_LOCK)
    !isnothing(cached) && first(cached) === rows && return last(cached)::NTuple{3, Vector{String}}
    # Parentheses in mission names describe ("OMNI (Combined 1AU IP Data; Magnetic and Solar Indices)")
    missions = [replace(_search_text(row, ("ObservatoryGroup", "Observatory")), r" *\([^)\n]*\)" => "") for row in rows]
    texts = ([_search_text(row) for row in rows], missions, [_search_text(row, ("Id", "Instrument")) for row in rows])
    lock(() -> _SEARCH_TEXTS[] = rows => texts, _METADATA_LOCK)
    return texts
end

function _search_text(row, fields = ("Id", "Label", "ObservatoryGroup", "Observatory", "Instrument", "InstrumentType"))
    io = IOBuffer()
    for k in fields
        v = get(row, k, nothing)
        for x in (v isa AbstractVector ? v : (v,))
            isnothing(x) || (print(io, x); write(io, '\n'))
        end
    end
    return String(take!(io))
end
