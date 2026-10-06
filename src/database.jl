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

            # Enable WAL mode for better concurrency
            DBInterface.execute(db, "PRAGMA journal_mode=WAL")
            DBInterface.execute(db, "PRAGMA synchronous=NORMAL")

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

"""Update orig cache metadata in SQLite database (process-safe, atomic)."""
function _update_cache!(dataset, start_times, end_times, files)
    db = _get_cache_db(true)
    # DBInterface.execute(db, "BEGIN TRANSACTION")

    # Remove overlapping entries first
    for (st, et) in zip(start_times, end_times)
        st_unix = _datetime_to_unix(st)
        et_unix = _datetime_to_unix(et)
        DBInterface.execute(
            db, """
                DELETE FROM cache
                WHERE dataset = ?
                AND start_time >= ?
                AND end_time <= ?
            """, (dataset, st_unix, et_unix)
        )
    end

    # Insert new entries
    for (st, et, file) in zip(start_times, end_times, files)
        st_unix = _datetime_to_unix(st)
        et_unix = _datetime_to_unix(et)
        DBInterface.execute(
            db, """
                INSERT OR REPLACE INTO cache (dataset, start_time, end_time, path)
                VALUES (?, ?, ?, ?)
            """, (dataset, st_unix, et_unix, file)
        )
    end

    # return DBInterface.execute(db, "COMMIT")
    return
end

"""Update variable cache metadata in SQLite database (process-safe, atomic)."""
function _update_cache!(dataset, variable, start_times, end_times, files)
    db = _get_cache_db(false)
    # DBInterface.execute(db, "BEGIN TRANSACTION")

    # Remove overlapping entries first
    for (st, et) in zip(start_times, end_times)
        st_unix = _datetime_to_unix(st)
        et_unix = _datetime_to_unix(et)
        DBInterface.execute(
            db, """
                DELETE FROM cache
                WHERE dataset = ?
                AND variable = ?
                AND start_time >= ?
                AND end_time <= ?
            """, (dataset, variable, st_unix, et_unix)
        )
    end

    # Insert new entries
    for (st, et, file) in zip(start_times, end_times, files)
        st_unix = _datetime_to_unix(st)
        et_unix = _datetime_to_unix(et)
        DBInterface.execute(
            db, """
                INSERT OR REPLACE INTO cache (dataset, variable, start_time, end_time, path)
                VALUES (?, ?, ?, ?, ?)
            """, (dataset, variable, st_unix, et_unix, file)
        )

    end
    # return DBInterface.execute(db, "COMMIT")
    return
end
