ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
  def database_size(name)
    select_value("SELECT pg_database_size(#{quote(name)})").to_i
  end

  def database_version
    select_value("SELECT version()")
  end

  def spid
    select_value("SELECT pg_backend_pid()").to_i
  end

  def xlog_location
    select_value("SELECT pg_current_xlog_insert_location()")
  end

  def xlog_location_diff(lsn1, lsn2)
    select_value("SELECT pg_xlog_location_diff(#{quote(lsn1)}, #{quote(lsn2)})").to_i
  end

  def client_connections
    select(<<-SQL, "Client Connections").to_a
                  SELECT client_addr   AS client_address
                       , datname       AS database
                       , pid           AS spid
                       , waiting       AS is_waiting
                       , query
                    FROM pg_stat_activity
                   ORDER BY 1, 2
                  SQL
  end

  # Taken from: https://github.com/bucardo/check_postgres/blob/2.19.0/check_postgres.pl#L3492
  # and referenced here: http://wiki.postgresql.org/wiki/Show_database_bloat
  # check_postgres is Copyright (C) 2007-2012, Greg Sabino Mullane
  #
  # Changes applied:
  # Removed  schemaname and totalwastedbytes columns from the original to fit our requirements.
  # Reformatted the SQL and renamed some columns to make them more easier to id.
  # Removed some CASE... logic statements as not needed for our requirements.
  def table_bloat
    data = select(<<-SQL, "Table Bloat")
                SELECT tablename                                                    AS table_name
                     , reltuples::bigint                                            AS rows
                     , relpages::bigint                                             AS pages
                     , otta
                     , ROUND(CASE WHEN otta = 0 OR sml.relpages = 0 OR sml.relpages = otta THEN 0.0
                             ELSE sml.relpages / otta::numeric END, 1)              AS percent_bloat
                     , CASE WHEN relpages < otta THEN 0
                             ELSE relpages::bigint - otta                    END    AS wasted_pages
                     , CASE WHEN relpages < otta THEN 0
                             ELSE (blocksize * (relpages - otta))::bigint    END    AS wasted_size
                     , CASE WHEN relpages < otta THEN 0
                             ELSE blocksize * (sml.relpages - otta)::bigint  END    AS wasted_bytes
                  FROM ( SELECT schemaname
                              , tablename
                              , cc.reltuples
                              , cc.relpages
                              , blocksize
                              , CEIL((cc.reltuples * ((datahdr + pagesize - (CASE WHEN datahdr%pagesize = 0 THEN pagesize
                                                                                  ELSE datahdr%pagesize END)) + nullhdr2 + 4)) / (blocksize - 20::float)
                                    ) AS otta
                           FROM ( SELECT pagesize
                                       , blocksize
                                       , schemaname
                                       , tablename
                                       , (datawidth + (hdr + pagesize - (CASE WHEN hdr%pagesize = 0 THEN pagesize
                                                                              ELSE hdr%pagesize END)))::numeric
                                                                                    AS datahdr
                                       , (maxfracsum * (nullhdr + pagesize - (CASE WHEN nullhdr%pagesize = 0 THEN pagesize
                                                                                   ELSE nullhdr%pagesize END)))
                                                                                    AS nullhdr2
                                    FROM ( SELECT schemaname
                                                , tablename
                                                , hdr
                                                , pagesize
                                                , blocksize
                                                , SUM((1 - null_frac) * avg_width)  AS datawidth
                                                , MAX(null_frac) AS maxfracsum
                                                , hdr + ( SELECT 1 + count(*) / 8
                                                            FROM pg_stats s2
                                                           WHERE null_frac     <> 0
                                                             AND s2.schemaname  = s.schemaname
                                                             AND s2.tablename   = s.tablename
                                                        ) AS nullhdr
                                             FROM pg_stats s
                                                , ( SELECT
                                                     ( SELECT current_setting('block_size')::numeric)     AS blocksize
                                                            , CASE WHEN SUBSTRING(SPLIT_PART(v, ' ', 2)
                                                         FROM '#"[0-9]+.[0-9]+#"%' for '#')
                                                           IN ('8.0','8.1','8.2') THEN 27 ELSE 23 END      AS hdr
                                                            , CASE WHEN v ~ 'mingw32' OR v ~ '64-bit' THEN 8
                                                                   ELSE 4 END                              AS pagesize
                                                      FROM ( SELECT version() AS v)                        AS foo
                                                  ) AS constants
                                             GROUP BY 1, 2, 3, 4, 5
                                          ) AS foo
                                ) AS rs
                        JOIN pg_class cc
                          ON cc.relname = rs.tablename
                        JOIN pg_namespace nn
                          ON cc.relnamespace = nn.oid
                         AND nn.nspname = rs.schemaname AND nn.nspname <> 'information_schema'
                ) AS sml
                WHERE schemaname = 'public'
                ORDER BY  1
            SQL

    integer_columns = %w(
      otta
      pages
      pagesize
      rows
      wasted_bytes
      wasted_pages
      wasted_size
    )

    float_columns = %w(
      percent_bloat
    )

    data.each do |datum|
      integer_columns.each   { |c| datum[c] = datum[c].to_i }
      float_columns.each     { |c| datum[c] = datum[c].to_f }
    end

    data.to_a
  end

  # Taken from: https://github.com/bucardo/check_postgres/blob/2.19.0/check_postgres.pl#L3492
  # and referenced here: http://wiki.postgresql.org/wiki/Show_database_bloat
  # check_postgres is Copyright (C) 2007-2012, Greg Sabino Mullane
  #
  # Changes applied:
  # Removed  schemaname and totalwastedbytes columns from the original to fit our requirements.
  # Reformatted the SQL and renamed some columns to make them more easier to id.
  def index_bloat
    data = select(<<-SQL, "Index Bloat")
                SELECT   tablename                                         AS table_name
                       , iname                                             AS index_name
                       , ituples::bigint                                   AS rows
                       , ipages::bigint                                    AS pages
                       , iotta                                             AS otta
                       , ROUND(CASE WHEN iotta = 0 OR ipages = 0 OR ipages = iotta THEN 0.0 ELSE ipages / iotta::numeric END, 1)   AS percent_bloat
                       , CASE WHEN ipages < iotta THEN 0 ELSE ipages::bigint - iotta                      END                      AS wasted_pages
                       , CASE WHEN ipages < iotta THEN 0 ELSE (blocksize * (ipages - iotta))::bigint      END                      AS wasted_size
                       , CASE WHEN ipages < iotta THEN 0 ELSE blocksize * (ipages - iotta)                END                      AS wasted_bytes

                 FROM ( SELECT   schemaname
                               , tablename
                               , cc.reltuples
                               , cc.relpages
                               , blocksize
                               , CEIL((cc.reltuples * ((datahdr + pagesize - (CASE WHEN datahdr%pagesize = 0 THEN pagesize
                                                                                   ELSE datahdr%pagesize END)) + nullhdr2 + 4)) / (blocksize - 20::float)
                                     )                                                                                             AS otta
                               , COALESCE(c2.relname,'?') AS iname, COALESCE(c2.reltuples, 0) AS ituples, COALESCE(c2.relpages, 0) AS ipages
                               , COALESCE(CEIL((c2.reltuples * (datahdr - 12)) / (blocksize - 20::float)), 0)                      AS iotta
                          FROM ( SELECT   pagesize
                                        , blocksize
                                        , schemaname
                                        , tablename
                                        , (datawidth + (hdr + pagesize - (case when hdr%pagesize = 0 THEN pagesize ELSE hdr%pagesize END)))::numeric       AS datahdr
                                        , (maxfracsum * (nullhdr + pagesize - (case when nullhdr%pagesize = 0 THEN pagesize ELSE nullhdr%pagesize END)))   AS nullhdr2
                                   FROM ( SELECT   schemaname
                                                 , tablename
                                                 , hdr
                                                 , pagesize
                                                 , blocksize
                                                 , SUM((1 - null_frac) * avg_width) AS datawidth
                                                 , MAX(null_frac) AS maxfracsum
                                                 , hdr + ( SELECT 1 + count(*) / 8
                                                             FROM pg_stats s2
                                                            WHERE null_frac     <> 0
                                                              AND s2.schemaname  = s.schemaname
                                                              AND s2.tablename   = s.tablename
                                                         ) AS nullhdr
                                            FROM  pg_stats s
                                                 , ( SELECT
                                                        (SELECT   current_setting('block_size')::numeric) AS blocksize
                                                                , CASE WHEN SUBSTRING(SPLIT_PART(v, ' ', 2) FROM '#"[0-9]+.[0-9]+#"%' for '#')
                                                                    IN ('8.0','8.1','8.2') THEN 27 ELSE 23 END AS hdr
                                                                , CASE WHEN v ~ 'mingw32' OR v ~ '64-bit' THEN 8 ELSE 4 END AS pagesize
                                                           FROM (SELECT version() AS v) AS foo
                                                  ) AS constants
                                            GROUP BY 1, 2, 3, 4, 5
                                        ) AS foo
                               ) AS rs
                          JOIN pg_class cc
                            ON cc.relname      = rs.tablename
                          JOIN pg_namespace nn
                            ON cc.relnamespace = nn.oid
                           AND nn.nspname      = rs.schemaname AND nn.nspname <> 'information_schema'
                          LEFT JOIN pg_index i
                            ON indrelid        = cc.oid
                          LEFT JOIN pg_class c2
                            ON c2.oid          = i.indexrelid
                        ) AS sml
                WHERE schemaname = 'public'
                ORDER BY  1, 2
           SQL

    integer_columns = %w(
      otta
      pages
      pagesize
      rows
      wasted_bytes
      wasted_pages
      wasted_size
    )

    float_columns = %w(
      percent_bloat
    )

    data.each do |datum|
      integer_columns.each   { |c| datum[c] = datum[c].to_i }
      float_columns.each     { |c| datum[c] = datum[c].to_f }
    end

    data.to_a
  end

  # Taken from: https://github.com/bucardo/check_postgres/blob/2.19.0/check_postgres.pl#L3492
  # and referenced here: http://wiki.postgresql.org/wiki/Show_database_bloat
  # check_postgres is Copyright (C) 2007-2012, Greg Sabino Mullane
  #
  # Changes applied:
  # Removed  schemaname and totalwastedbytes columns from the original to fit our requirements.
  # Reformatted the SQL and renamed some columns to make them more easier to id.
  # Changed to a UNION so that it is easier to read the output and to separate table stats from idx stats.
  def database_bloat
    data = select(<<-SQL, "Database Bloat")
              SELECT   tablename                                         AS table_name
                     , ' '                                               AS index_name
                     , reltuples::bigint                                 AS rows
                     , relpages::bigint                                  AS pages
                     , otta
                     , ROUND(CASE WHEN otta = 0 OR sml.relpages = 0 OR sml.relpages = otta THEN 0.0 ELSE sml.relpages / otta::numeric END, 1) AS percent_bloat
                     , CASE WHEN relpages < otta THEN 0 ELSE relpages::bigint - otta                    END                                   AS wasted_pages
                     , CASE WHEN relpages < otta THEN 0 ELSE (blocksize * (relpages - otta))::bigint    END                                   AS wasted_size
                     , CASE WHEN relpages < otta THEN 0 ELSE blocksize * (sml.relpages - otta)::bigint  END                                   AS wasted_bytes
               FROM ( SELECT   schemaname
                             , tablename
                             , cc.reltuples
                             , cc.relpages
                             , blocksize
                             , CEIL((cc.reltuples * ((datahdr + pagesize - (CASE WHEN datahdr % pagesize = 0 THEN pagesize
                                                                                 ELSE datahdr % pagesize END)) + nullhdr2 + 4)) / (blocksize - 20::float)
                                   )                                                                                                          AS otta
                        FROM ( SELECT   pagesize
                                      , blocksize
                                      , schemaname
                                      , tablename
                                      , (datawidth + (hdr + pagesize - (CASE WHEN hdr%pagesize = 0 THEN pagesize
                                                                             ELSE hdr%pagesize END)))::numeric                                AS datahdr
                                      , (maxfracsum * (nullhdr + pagesize - (CASE WHEN nullhdr % pagesize = 0 THEN pagesize
                                                                                  ELSE nullhdr % pagesize END)))                              AS nullhdr2
                                 FROM ( SELECT   schemaname
                                               , tablename
                                               , hdr
                                               , pagesize
                                               , blocksize
                                               , SUM((1 - null_frac) * avg_width)                                                             AS datawidth
                                               , MAX(null_frac)                                                                               AS maxfracsum
                                               , hdr + ( SELECT 1 + count(*) / 8
                                                           FROM pg_stats s2
                                                          WHERE null_frac     <> 0
                                                            AND s2.schemaname  = s.schemaname
                                                            AND s2.tablename   = s.tablename
                                                       )                                                                                      AS nullhdr
                                          FROM  pg_stats s
                                               , ( SELECT
                                                      ( SELECT   current_setting('block_size')::numeric)                                      AS blocksize
                                                               , CASE WHEN SUBSTRING(SPLIT_PART(v, ' ', 2) FROM '#"[0-9]+.[0-9]+#"%' for '#')
                                                                   IN ('8.0','8.1','8.2') THEN 27 ELSE 23 END                                 AS hdr
                                                               , CASE WHEN v ~ 'mingw32' OR v ~ '64-bit' THEN 8 ELSE 4 END                    AS pagesize
                                                          FROM ( SELECT version() AS v) AS foo
                                                ) AS constants
                                          GROUP BY 1, 2, 3, 4, 5
                                      ) AS foo
                             ) AS rs
                        JOIN pg_class cc
                          ON cc.relname = rs.tablename
                        JOIN pg_namespace nn
                          ON cc.relnamespace = nn.oid
                         AND nn.nspname      = rs.schemaname
                         AND nn.nspname     <> 'information_schema'
                      ) AS sml
              WHERE schemaname = 'public'

            UNION

              SELECT   tablename                                           AS table_name
                     , iname                                               AS index_name
                     , ituples::bigint                                     AS rows
                     , ipages::bigint                                      AS pages
                     , iotta                                               AS otta
                     , ROUND(CASE WHEN iotta = 0 OR ipages = 0 OR ipages = iotta THEN 0.0 ELSE ipages / iotta::numeric END, 1)                AS percent_bloat
                     , CASE WHEN ipages < iotta THEN 0 ELSE ipages::bigint - iotta                      END                                   AS wasted_pages
                     , CASE WHEN ipages < iotta THEN 0 ELSE (blocksize * (ipages - iotta))::bigint      END                                   AS wasted_size
                     , CASE WHEN ipages < iotta THEN 0 ELSE blocksize * (ipages - iotta)                END                                   AS wasted_bytes

               FROM ( SELECT   schemaname
                             , tablename
                             , cc.reltuples
                             , cc.relpages
                             , blocksize
                             , CEIL((cc.reltuples * ((datahdr + pagesize - (CASE WHEN datahdr % pagesize = 0 THEN pagesize
                                                                                 ELSE datahdr % pagesize END)) + nullhdr2 + 4)) / (blocksize - 20::float)
                                   )                                                                                                          AS otta
                             , COALESCE(c2.relname,'?') AS iname, COALESCE(c2.reltuples, 0) AS ituples, COALESCE(c2.relpages, 0)              AS ipages
                             , COALESCE(CEIL((c2.reltuples * (datahdr - 12)) / (blocksize - 20::float)), 0)                                   AS iotta
                        FROM ( SELECT   pagesize
                                      , blocksize
                                      , schemaname
                                      , tablename
                                      , (datawidth + (hdr + pagesize - ( CASE WHEN hdr%pagesize = 0 THEN pagesize
                                                                              ELSE hdr%pagesize END)))::numeric                               AS datahdr
                                      , (maxfracsum * (nullhdr + pagesize - ( CASE WHEN nullhdr % pagesize = 0 THEN pagesize
                                                                                   ELSE nullhdr % pagesize END)))                             AS nullhdr2
                                 FROM ( SELECT   schemaname
                                               , tablename
                                               , hdr
                                               , pagesize
                                               , blocksize
                                               , SUM((1 - null_frac) * avg_width)                                                             AS datawidth
                                               , MAX(null_frac)                                                                               AS maxfracsum
                                               , hdr + ( SELECT 1 + count(*) / 8
                                                           FROM pg_stats s2
                                                          WHERE null_frac     <> 0
                                                            AND s2.schemaname  = s.schemaname
                                                            AND s2.tablename   = s.tablename
                                                       )                                                                                      AS nullhdr
                                          FROM  pg_stats s
                                               , ( SELECT
                                                      ( SELECT   current_setting('block_size')::numeric)                                      AS blocksize
                                                               , CASE WHEN SUBSTRING(SPLIT_PART(v, ' ', 2) FROM '#"[0-9]+.[0-9]+#"%' for '#')
                                                                   IN ('8.0','8.1','8.2') THEN 27 ELSE 23 END                                 AS hdr
                                                               , CASE WHEN v ~ 'mingw32' OR v ~ '64-bit' THEN 8 ELSE 4 END                    AS pagesize
                                                          FROM ( SELECT version() AS v) AS foo
                                                ) AS constants
                                          GROUP BY 1, 2, 3, 4, 5
                                      ) AS foo
                             ) AS rs
                        JOIN pg_class cc
                          ON cc.relname      = rs.tablename
                        JOIN pg_namespace nn
                          ON cc.relnamespace = nn.oid
                         AND nn.nspname      = rs.schemaname
                         AND nn.nspname     <> 'information_schema'
                        LEFT JOIN pg_index i
                          ON indrelid        = cc.oid
                        LEFT JOIN pg_class c2
                          ON c2.oid          = i.indexrelid
                      ) AS sml
              WHERE schemaname = 'public'
              ORDER BY  1, 2
           SQL

    integer_columns = %w(
      otta
      pages
      pagesize
      rows
      wasted_bytes
      wasted_pages
      wasted_size
    )

    float_columns = %w(
      percent_bloat
    )

    data.each do |datum|
      integer_columns.each   { |c| datum[c] = datum[c].to_i }
      float_columns.each     { |c| datum[c] = datum[c].to_f }
    end

    data.to_a
  end

  def table_statistics
    data = select(<<-SQL, "Table Statistics")
                SELECT relname            AS table_name
                     , seq_scan           AS table_scans
                     , seq_tup_read       AS sequential_rows_read
                     , idx_scan           AS index_scans
                     , idx_tup_fetch      AS index_rows_fetched
                     , n_tup_ins          AS rows_inserted
                     , n_tup_upd          AS rows_updated
                     , n_tup_del          AS rows_deleted
                     , n_tup_hot_upd      AS rows_hot_updated
                     , n_live_tup         AS rows_live
                     , n_dead_tup         AS rows_dead
                     , last_vacuum        AS last_vacuum_date
                     , last_autovacuum    AS last_autovacuum_date
                     , last_analyze       AS last_analyze_date
                     , last_autoanalyze   AS last_autoanalyze_date
                  FROM pg_stat_all_tables
                 WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
                 ORDER BY relname ASC ;
                 SQL

    integer_columns = %w(
      table_scans
      sequential_rows_read
      index_scans
      index_rows_fetched
      rows_inserted
      rows_updated
      rows_deleted
      rows_hot_updated
      rows_live
      rows_dead
    )

    timestamp_columns = %w(
      last_vacuum_date
      last_autovacuum_date
      last_analyze_date
      last_autoanalyze_date
    )

    data.each do |datum|
      integer_columns.each   { |c| datum[c] = datum[c].to_i }
      timestamp_columns.each { |c| datum[c] = ActiveRecord::Type::Time.new.deserialize(datum[c]) }
    end

    data.to_a
  end

  # Provide the database statistics for all tables and indexes
  def statistics
    stats = select(<<-SQL, "Statistics")
      SELECT relname           AS name,
             reltuples         AS rows,
             relpages          AS pages
      FROM pg_class
      ORDER BY reltuples DESC, relpages DESC
    SQL

    stats.each do |s|
      s["rows"]  = s["rows"].to_f.to_i
      s["pages"] = s["pages"].to_f.to_i
      s["size"]  = s["pages"] * 8 * 1024
      s["average_row_size"] = s["pages"].to_f / (s["rows"] + 1) * 8 * 1024
    end

    stats.to_a
  end

  def table_size
    stats = select(<<-SQL, "Table Size")
                SELECT relname                                                           AS table_name
                     , reltuples                                                         AS rows
                     , relpages                                                          AS pages
                  FROM pg_class
                 WHERE reltuples > 1
                   AND relname NOT LIKE 'pg_%'
              ORDER BY reltuples DESC
                     , relpages  DESC ;
                 SQL

    stats.each do |s|
      s["rows"]  = s["rows"].to_f.to_i
      s["pages"] = s["pages"].to_f.to_i
      s["size"]  = s["pages"] * 8 * 1024
      s["average_row_size"] = s["pages"].to_f / (s["rows"] + 1) * 8 * 1024
    end

    stats.to_a
  end

  def table_total_size(table)
    select_value("SELECT pg_total_relation_size('#{table}')").to_i
  end

  def text_tables(table)
    data = select(<<-SQL, "Text Tables")
      SELECT relname AS table_name
      FROM pg_class,
           (SELECT reltoastrelid
            FROM pg_class
            WHERE relname = '#{table}') tt
      WHERE oid = tt.reltoastrelid
      ORDER BY relname
    SQL

    data.collect { |h| h['table_name'] }
  end

  # Returns an array of toast table indexes for the given toast table.
  def text_table_indexes(table_name, name = "Text Table Indexes")
    result = query(<<-SQL, name)
       SELECT distinct i.relname, d.indisunique, d.indkey, i.oid
       FROM pg_class t
       INNER JOIN pg_index d ON t.oid = d.indrelid
       INNER JOIN pg_class i ON d.indexrelid = i.oid
       WHERE i.relkind = 'i'
         AND t.relkind = 't'
         AND i.oid = d.indexrelid
         AND t.relname = '#{table_name}'
         AND i.relnamespace IN (SELECT oid FROM pg_namespace WHERE nspname = 'pg_toast' )
      ORDER BY i.relname
    SQL

    result.map do |row|
      index_name = row[0]
      unique     = row[1] == 't'
      indkey     = row[2].split(" ")
      oid        = row[3]

      columns = Hash[query(<<-SQL, "Columns for index #{index_name} on #{table_name}")]
      SELECT a.attnum, a.attname
      FROM pg_attribute a
      WHERE a.attrelid = #{oid}
      AND a.attnum IN (#{indkey.join(",")})
      SQL

      column_names = columns.values_at(*indkey).compact
      column_names.empty? ? nil : IndexDefinition.new(table_name, index_name, unique, column_names)
    end.compact
  end

  # Returns the primary-key index definition for the given table if it exists
  def primary_key_index(table_name)
    result = select_all(<<-SQL).cast_values.first
      SELECT c.relname, array_agg(a.attname)
      FROM pg_index i
      JOIN pg_attribute a ON
        a.attrelid = i.indrelid AND
        a.attnum = ANY(i.indkey)
      JOIN pg_class c ON
        i.indexrelid = c.oid
      WHERE
        i.indrelid = '#{table_name}'::regclass AND
        i.indisprimary group by c.relname;
    SQL

    return nil unless result

    ActiveRecord::ConnectionAdapters::IndexDefinition.new(table_name, result[0], true, result[1])
  end

  def primary_key?(table_name)
    select_value(<<-SQL)
      SELECT EXISTS(
        SELECT 1
        FROM pg_index
        WHERE indrelid = '#{table_name}'::regclass AND indisprimary = true
      )
    SQL
  end

  def table_metrics_bloat(table_name)
    data = select(<<-SQL, "Table Metrics Bloat Analysis")
            SELECT tablename                                                    AS table_name
                 , reltuples::bigint                                            AS rows
                 , relpages::bigint                                             AS pages
                 , otta
                 , ROUND(CASE WHEN otta = 0 OR sml.relpages = 0 OR sml.relpages = otta THEN 0.0
                         ELSE sml.relpages / otta::numeric END, 1)              AS percent_bloat
                 , CASE WHEN relpages < otta THEN 0
                         ELSE relpages::bigint - otta                    END    AS wasted_pages
                 , CASE WHEN relpages < otta THEN 0
                         ELSE (blocksize * (relpages - otta))::bigint    END    AS wasted_size
                 , CASE WHEN relpages < otta THEN 0
                         ELSE blocksize * (sml.relpages - otta)::bigint  END    AS wasted_bytes
              FROM ( SELECT schemaname
                          , tablename
                          , cc.reltuples
                          , cc.relpages
                          , blocksize
                          , CEIL((cc.reltuples * ((datahdr + pagesize - (CASE WHEN datahdr%pagesize = 0 THEN pagesize
                                                                              ELSE datahdr%pagesize END)) + nullhdr2 + 4)) / (blocksize - 20::float)
                                ) AS otta
                       FROM ( SELECT pagesize
                                   , blocksize
                                   , schemaname
                                   , tablename
                                   , (datawidth + (hdr + pagesize - (CASE WHEN hdr%pagesize = 0 THEN pagesize
                                                                          ELSE hdr%pagesize END)))::numeric
                                                                                AS datahdr
                                   , (maxfracsum * (nullhdr + pagesize - (CASE WHEN nullhdr%pagesize = 0 THEN pagesize
                                                                               ELSE nullhdr%pagesize END)))
                                                                                AS nullhdr2
                                FROM ( SELECT schemaname
                                            , tablename
                                            , hdr
                                            , pagesize
                                            , blocksize
                                            , SUM((1 - null_frac) * avg_width)  AS datawidth
                                            , MAX(null_frac) AS maxfracsum
                                            , hdr + ( SELECT 1 + count(*) / 8
                                                        FROM pg_stats s2
                                                       WHERE null_frac     <> 0
                                                         AND s2.schemaname  = s.schemaname
                                                         AND s2.tablename   = s.tablename
                                                    ) AS nullhdr
                                         FROM pg_stats s
                                            , ( SELECT
                                                 ( SELECT current_setting('block_size')::numeric)     AS blocksize
                                                        , CASE WHEN SUBSTRING(SPLIT_PART(v, ' ', 2)
                                                     FROM '#"[0-9]+.[0-9]+#"%' for '#')
                                                       IN ('8.0','8.1','8.2') THEN 27 ELSE 23 END      AS hdr
                                                        , CASE WHEN v ~ 'mingw32' OR v ~ '64-bit' THEN 8
                                                               ELSE 4 END                              AS pagesize
                                                  FROM ( SELECT version() AS v)                        AS foo
                                              ) AS constants
                                         GROUP BY 1, 2, 3, 4, 5
                                      ) AS foo
                            ) AS rs
                    JOIN pg_class cc
                      ON cc.relname = rs.tablename
                    JOIN pg_namespace nn
                      ON cc.relnamespace = nn.oid
                     AND nn.nspname = rs.schemaname AND nn.nspname <> 'information_schema'
            ) AS sml
            WHERE schemaname = 'public'
              AND tablename  = '#{table_name}'
            ORDER BY  1
        SQL

    integer_columns = %w(
      otta
      pages
      rows
      wasted_bytes
      wasted_pages
      wasted_size
    )

    float_columns = %w(
      percent_bloat
    )

    data.each do |datum|
      integer_columns.each   { |c| datum[c] = datum[c].to_i }
      float_columns.each     { |c| datum[c] = datum[c].to_f }
    end

    data.to_a
  end

  def table_metrics_analysis(table_name)
    data = select(<<-SQL, "Table Metrics Stats Analysis")
              SELECT seq_scan           AS table_scans
                   , seq_tup_read       AS sequential_rows_read
                   , idx_scan           AS index_scans
                   , idx_tup_fetch      AS index_rows_fetched
                   , n_tup_ins          AS rows_inserted
                   , n_tup_upd          AS rows_updated
                   , n_tup_del          AS rows_deleted
                   , n_tup_hot_upd      AS rows_hot_updated
                   , n_live_tup         AS rows_live
                   , n_dead_tup         AS rows_dead
                   , last_vacuum        AS last_vacuum_date
                   , last_autovacuum    AS last_autovacuum_date
                   , last_analyze       AS last_analyze_date
                   , last_autoanalyze   AS last_autoanalyze_date
                FROM pg_stat_all_tables
               WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
                 AND relname = '#{table_name}'
               ORDER BY relname ASC ;
            SQL

    integer_columns = %w(
      table_scans
      sequential_rows_read
      index_scans
      index_rows_fetched
      rows_inserted
      rows_updated
      rows_deleted
      rows_hot_updated
      rows_live
      rows_dead
    )

    timestamp_columns = %w(
      last_vacuum_date
      last_autovacuum_date
      last_analyze_date
      last_autoanalyze_date
    )

    data.each do |datum|
      integer_columns.each   { |c| datum[c] = datum[c].to_i }
      timestamp_columns.each { |c| datum[c] = ActiveRecord::Type::Time.new.deserialize(datum[c]) }
    end

    data.to_a
  end

  def table_metrics_total_size(table_name)
    select_value(<<-SQL, "Table Metrics Total Size").to_i
            SELECT pg_total_relation_size('#{table_name}'::regclass) AS total_table_size;
           SQL
  end

  def number_of_db_connections
    select_value(<<-SQL, "DB Client Connections").to_i
            SELECT count(*) as active_connections
              FROM pg_stat_activity
           SQL
  end

  def index_metrics_bloat(index_name)
    data = select(<<-SQL, "Index Metrics Bloat Analysis")
                SELECT   tablename                                         AS table_name
                       , iname                                             AS index_name
                       , ituples::bigint                                   AS rows
                       , ipages::bigint                                    AS pages
                       , iotta                                             AS otta
                       , ROUND(CASE WHEN iotta = 0 OR ipages = 0 OR ipages = iotta THEN 0.0 ELSE ipages / iotta::numeric END, 1)   AS percent_bloat
                       , CASE WHEN ipages < iotta THEN 0 ELSE ipages::bigint - iotta                      END                      AS wasted_pages
                       , CASE WHEN ipages < iotta THEN 0 ELSE (blocksize * (ipages - iotta))::bigint      END                      AS wasted_size
                       , CASE WHEN ipages < iotta THEN 0 ELSE blocksize * (ipages - iotta)                END                      AS wasted_bytes

                 FROM ( SELECT   schemaname
                               , tablename
                               , cc.reltuples
                               , cc.relpages
                               , blocksize
                               , CEIL((cc.reltuples * ((datahdr + pagesize - (CASE WHEN datahdr%pagesize = 0 THEN pagesize
                                                                                   ELSE datahdr%pagesize END)) + nullhdr2 + 4)) / (blocksize - 20::float)
                                     )                                                                                             AS otta
                               , COALESCE(c2.relname,'?') AS iname, COALESCE(c2.reltuples, 0) AS ituples, COALESCE(c2.relpages, 0) AS ipages
                               , COALESCE(CEIL((c2.reltuples * (datahdr - 12)) / (blocksize - 20::float)), 0)                      AS iotta
                          FROM ( SELECT   pagesize
                                        , blocksize
                                        , schemaname
                                        , tablename
                                        , (datawidth + (hdr + pagesize - (case when hdr%pagesize = 0 THEN pagesize ELSE hdr%pagesize END)))::numeric       AS datahdr
                                        , (maxfracsum * (nullhdr + pagesize - (case when nullhdr%pagesize = 0 THEN pagesize ELSE nullhdr%pagesize END)))   AS nullhdr2
                                   FROM ( SELECT   schemaname
                                                 , tablename
                                                 , hdr
                                                 , pagesize
                                                 , blocksize
                                                 , SUM((1 - null_frac) * avg_width) AS datawidth
                                                 , MAX(null_frac) AS maxfracsum
                                                 , hdr + ( SELECT 1 + count(*) / 8
                                                             FROM pg_stats s2
                                                            WHERE null_frac     <> 0
                                                              AND s2.schemaname  = s.schemaname
                                                              AND s2.tablename   = s.tablename
                                                         ) AS nullhdr
                                            FROM  pg_stats s
                                                 , ( SELECT
                                                        (SELECT   current_setting('block_size')::numeric) AS blocksize
                                                                , CASE WHEN SUBSTRING(SPLIT_PART(v, ' ', 2) FROM '#"[0-9]+.[0-9]+#"%' for '#')
                                                                    IN ('8.0','8.1','8.2') THEN 27 ELSE 23 END AS hdr
                                                                , CASE WHEN v ~ 'mingw32' OR v ~ '64-bit' THEN 8 ELSE 4 END AS pagesize
                                                           FROM (SELECT version() AS v) AS foo
                                                  ) AS constants
                                            GROUP BY 1, 2, 3, 4, 5
                                        ) AS foo
                               ) AS rs
                          JOIN pg_class cc
                            ON cc.relname      = rs.tablename
                          JOIN pg_namespace nn
                            ON cc.relnamespace = nn.oid
                           AND nn.nspname      = rs.schemaname AND nn.nspname <> 'information_schema'
                          LEFT JOIN pg_index i
                            ON indrelid        = cc.oid
                          LEFT JOIN pg_class c2
                            ON c2.oid          = i.indexrelid
                        ) AS sml
                WHERE iname  = '#{index_name}'
                ORDER BY  1, 2
           SQL

    integer_columns = %w(
      otta
      pages
      pagesize
      rows
      wasted_bytes
      wasted_pages
      wasted_size
    )

    float_columns = %w(
      percent_bloat
    )

    data.each do |datum|
      integer_columns.each   { |c| datum[c] = datum[c].to_i }
      float_columns.each     { |c| datum[c] = datum[c].to_f }
    end

    data.to_a
  end

  def index_metrics_analysis(index_name)
    data = select(<<-SQL, "Index Metrics Stats Analysis")
              SELECT relid                    AS table_id
                   , indexrelid               AS index_id
                   , schemaname
                   , relname                  AS table_name
                   , indexrelname             AS index_name
                   , idx_scan                 AS index_scans
                   , idx_tup_read             AS index_rows_read
                   , idx_tup_fetch            AS index_rows_fetched
                FROM pg_stat_user_indexes
               WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
                 AND indexrelname = '#{index_name}' ;
            SQL

    integer_columns = %w(
      table_id
      index_id
      index_scans
      index_rows_read
      index_rows_fetched
    )

    data.each do |datum|
      integer_columns.each   { |c| datum[c] = datum[c].to_i }
    end

    data.to_a
  end

  def index_metrics_total_size(_index_name)
    select_value(<<-SQL, "Index Metrics -  Size").to_i
            SELECT pg_total_relation_size('#{table_name}'::regclass) - pg_relation_size('#{table_name}') AS index_size;
           SQL
  end
  #

  # DBA operations
  #

  # Fetch data directory
  def data_directory
    select_value(<<-SQL, "Select data directory")
                    SELECT setting AS path
                      FROM pg_settings
                     WHERE name = 'data_directory'
                 SQL
  end

  # Fetch PostgreSQL last start date/time
  def last_start_time
    start_time = select_value(<<-SQL, "Select last start date/time")
                                 SELECT pg_postmaster_start_time()
                              SQL
    ActiveRecord::Type::DateTime.new.deserialize(start_time)
  end

  def analyze_table(table)
    execute("ANALYZE #{quote_table_name(table)}")
  end

  def reindex_table(table)
    execute("REINDEX TABLE #{quote_table_name(table)}")
  end

  def vacuum_analyze_table(table)
    execute("VACUUM ANALYZE #{quote_table_name(table)}")
  end

  def vacuum_full_analyze_table(table)
    execute("VACUUM FULL ANALYZE #{quote_table_name(table)}")
  end
end
