# SQLite-based cache implementation for thread and process safety

# Connection cache - reuse connections instead of opening new ones
const _DB_CACHE_VARIABLE = Ref{Union{SQLite.DB, Nothing}}(nothing)
const _DB_CACHE_ORIG = Ref{Union{SQLite.DB, Nothing}}(nothing)
const _DB_LOCK = ReentrantLock()

# Prepared lazily; only used under `_DB_LOCK`
const _STMT_ORIG_CACHE = Ref{Union{SQLite.Stmt, Nothing}}(nothing)
const _STMT_VARIABLE_CACHE = Ref{Union{SQLite.Stmt, Nothing}}(nothing)

# Helper functions for Unix timestamp conversion
# https://www.sqlite.org/datatype3.html
# https://sqlite.org/lang_datefunc.html
@inline _datetime_to_unix(dt::DateTime) = round(Int, Dates.datetime2unix(dt))

# Columns identifying a cache entry besides its time range; `variable` is empty for the orig cache
_key_columns(variable) = isempty(variable) ? ("dataset",) : ("dataset", "variable")
_key_match(variable) = join(("$c = ?" for c in _key_columns(variable)), " AND ")

function _get_cache_db_file(orig::Bool)
    return joinpath(BASE_PATH[], "cache_$(orig ? "orig" : "variable").sqlite")
end

"""Initialize or get existing cache database with proper schema and settings."""
function _get_cache_db(orig::Bool)
    return lock(_DB_LOCK) do
        db_ref = orig ? _DB_CACHE_ORIG : _DB_CACHE_VARIABLE

        if isnothing(db_ref[])
            mkpath(BASE_PATH[])
            db_file = _get_cache_db_file(orig)
            db = SQLite.DB(db_file)

            # Wait for other processes' writes instead of failing with SQLITE_BUSY
            SQLite.busy_timeout(db, 10_000)
            # Not WAL: it needs shared memory, so it breaks when the cache is on a network
            # filesystem shared across hosts (e.g. an HPC home). The mode persists in the file,
            # so set it explicitly to convert caches created in WAL mode. Leaving WAL fails at once
            # (no busy wait) while another connection is open; the file then stays WAL until a later open.
            # `SQLite.execute` finalizes at once; a pending PRAGMA row would block COMMIT
            try
                SQLite.execute(db, "PRAGMA journal_mode=DELETE")
            catch e
                e isa SQLite.SQLiteException || rethrow()
            end

            # Create schema if not exists (using INTEGER for Unix timestamps)
            schema = if orig
                """CREATE TABLE IF NOT EXISTS cache (
                    dataset TEXT NOT NULL,
                    start_time INTEGER NOT NULL,
                    end_time INTEGER NOT NULL,
                    path TEXT NOT NULL,
                    PRIMARY KEY (dataset, start_time, end_time)
                )"""
            else
                """CREATE TABLE IF NOT EXISTS cache (
                    dataset TEXT NOT NULL,
                    variable TEXT NOT NULL,
                    start_time INTEGER NOT NULL,
                    end_time INTEGER NOT NULL,
                    path TEXT NOT NULL,
                    PRIMARY KEY (dataset, variable, start_time, end_time)
                )"""
            end

            DBInterface.execute(db, schema)

            # Create indices for faster queries
            if orig
                DBInterface.execute(db, "CREATE INDEX IF NOT EXISTS idx_dataset ON cache(dataset)")
                DBInterface.execute(db, "CREATE INDEX IF NOT EXISTS idx_time_range ON cache(start_time, end_time)")
            else
                DBInterface.execute(db, "CREATE INDEX IF NOT EXISTS idx_dataset_var ON cache(dataset, variable)")
                DBInterface.execute(db, "CREATE INDEX IF NOT EXISTS idx_time_range ON cache(start_time, end_time)")
            end

            db_ref[] = db
        end

        return db_ref[]
    end
end

function _close_cache_db!()
    lock(_DB_LOCK) do
        for ref in (_STMT_ORIG_CACHE, _STMT_VARIABLE_CACHE, _DB_CACHE_ORIG, _DB_CACHE_VARIABLE)
            isnothing(ref[]) || DBInterface.close!(ref[])
            ref[] = nothing
        end
    end
    return
end

# Entries overlapping [start_time, stop_time] as `(start, end, path)`, ordered by start.
# Materialized under the lock: two tasks can't iterate one prepared statement.
function _query(start_time, stop_time, dataset, variable...)
    orig = isempty(variable)
    params = (dataset, variable..., _datetime_to_unix(stop_time), _datetime_to_unix(start_time))
    return lock(_DB_LOCK) do
        ref = orig ? _STMT_ORIG_CACHE : _STMT_VARIABLE_CACHE
        if isnothing(ref[])
            ref[] = DBInterface.prepare(
                _get_cache_db(orig), """SELECT start_time, end_time, path FROM cache
                WHERE $(_key_match(variable)) AND start_time < ? AND end_time >= ? ORDER BY start_time"""
            )
        end
        [(unix2datetime(r[1]), unix2datetime(r[2]), String(r[3])) for r in DBInterface.execute(ref[], params)]
    end
end

"""Replace cache entries inside each new entry's time range, atomically."""
function _update_cache!(start_times, end_times, files, dataset, variable...)
    key = (dataset, variable...)
    cols = join(_key_columns(variable), ", ")
    placeholders = join(fill("?", length(key) + 3), ", ")
    unix = _datetime_to_unix
    lock(_DB_LOCK) do
        db = _get_cache_db(isempty(variable))
        # Not `SQLite.transaction`, which sets `synchronous = OFF` on the connection
        SQLite.execute(db, "BEGIN IMMEDIATE")
        try
            for (st, et) in zip(start_times, end_times)
                SQLite.execute(
                    db, "DELETE FROM cache WHERE $(_key_match(variable)) AND start_time >= ? AND end_time <= ?",
                    (key..., unix(st), unix(et))
                )
            end
            for (st, et, file) in zip(start_times, end_times, files)
                SQLite.execute(
                    db, "INSERT OR REPLACE INTO cache ($cols, start_time, end_time, path) VALUES ($placeholders)",
                    (key..., unix(st), unix(et), file)
                )
            end
            SQLite.execute(db, "COMMIT")
        catch
            SQLite.execute(db, "ROLLBACK")
            rethrow()
        end
    end
    return
end
