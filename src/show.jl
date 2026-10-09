function Base.show(io::IO, ::MIME"text/plain", ds::Dataset)
    print(io, ds.id, "  ", _range(ds), "  ", _label(ds.metadata))
    ds.direct && print(io, "  (direct)")
end

# Labels end in " - PI (affiliation)", a third of their length and no help in choosing a dataset
function _label(row)
    label, pi = row["Label"]::String, get(row, "PiName", nothing)
    isnothing(pi) && return label
    i = findlast(" - " * pi, label)
    return _squeeze(isnothing(i) ? label : label[1:prevind(label, first(i))])
end

_range(ds::Dataset) = (t = ds.metadata["TimeInterval"]; first(t["Start"], 10) * ".." * first(t["End"], 10))

function Base.show(io::IO, m::MIME"text/plain", v::AbstractVector{Dataset})
    _show_rows(io, v, "CDAWeb datasets", v) do ds
        show(io, m, ds)
    end
end

# Variables under a header line per dataset (id, time range), which runs of them share
function Base.show(io::IO, ::MIME"text/plain", v::AbstractVector{Variable})
    descs = Dict{String, Dict{String, String}}()
    prev = Ref{Union{Nothing, Dataset}}(nothing)
    _show_rows(io, v, "CDAWeb variables", [x.dataset for x in v]) do x
        ds = x.dataset
        if ds != prev[]
            println(io, ds.id, "  ", _range(ds))
            prev[] = ds
        end
        desc = get(get!(() -> _descriptions(ds.id), descs, ds.id), x.name, "")
        print(io, "  ", x.name)
        isempty(desc) || print(io, "  ", desc)
    end
end

# Showing must not fail offline: a master CDF may need fetching
function _descriptions(id)
    return try
        Dict(v.name => v.description for v in _variables(id))
    catch
        Dict{String, String}()
    end
end

# A limited display (REPL, `display`) stops at `_MAX_ROWS`, unlike Base's truncation, which hides the
# middle silently: the footer counts matches per id prefix (spacecraft code), the term to add
const _MAX_ROWS = 80

function _show_rows(f, io, rows, noun, datasets)
    print(io, length(rows), " ", noun, isempty(rows) ? "" : ":")
    limited = get(io, :limit, false) && length(rows) > _MAX_ROWS
    for x in (limited ? view(rows, 1:_MAX_ROWS) : rows)
        println(io)
        f(x)
    end
    limited || return
    print(io, "\n… ", length(rows) - _MAX_ROWS, " more; narrow by adding a term")
    counts = Dict{String, Int}()
    for ds in datasets
        k = first(split(ds.id, r"[^[:alnum:]]"))
        counts[k] = get(counts, k, 0) + 1
    end
    length(counts) > 1 || return
    top = first(sort!(collect(counts); by = c -> (-last(c), first(c))), 12)
    print(io, ". Matches per id prefix: ", join(("$k $c" for (k, c) in top), ", "), length(counts) > 12 ? ", …" : "")
end
