module Dba
  def self.select(*args)
    ActiveRecord::Base.connection.send(:select, *args)
  end

  #
  # Extended PostgreSQL DBA functionality
  #
  def self.client_connections
    all_connections = select(<<-SQL, "Client Connections")
                      SELECT client_addr   AS client_address
                           , datname       AS database
                           , procpid       AS spid
                           , waiting       AS number_waiting
                           , current_query AS query
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
  # Changed to a UNION so that it is easier to read the output and to separate table stats from idx stats.
  def self.database_bloat
    db_array = select(<<-SQL, "Database Bloat")
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
  end


  # Taken from: https://github.com/bucardo/check_postgres/blob/2.19.0/check_postgres.pl#L3492
  # and referenced here: http://wiki.postgresql.org/wiki/Show_database_bloat
  # check_postgres is Copyright (C) 2007-2012, Greg Sabino Mullane
  #
  # Changes applied:
  # Removed  schemaname and totalwastedbytes columns from the original to fit our requirements.
  # Reformatted the SQL and renamed some columns to make them more easier to id.
  # Removed some CASE... logic statements as not needed for our requirements.
  def self.table_bloat
    tbl_array = select(<<-SQL, "Table Bloat")
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
  end

  # Taken from: https://github.com/bucardo/check_postgres/blob/2.19.0/check_postgres.pl#L3492
  # and referenced here: http://wiki.postgresql.org/wiki/Show_database_bloat
  # check_postgres is Copyright (C) 2007-2012, Greg Sabino Mullane
  #
  # Changes applied:
  # Removed  schemaname and totalwastedbytes columns from the original to fit our requirements.
  # Reformatted the SQL and renamed some columns to make them more easier to id.
  def self.index_bloat
    idx_array = select(<<-SQL, "Index Bloat")
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
  end

  # Provide the database statistics for all tables and indexes
  def self.database_statistics
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

    return stats
  end

  def self.table_statistics
    tbl_stats_array = select(<<-SQL, "Table Statistics")
                SELECT relname            AS table_name
                     , seq_scan           AS table_scan
                     , seq_tup_read       AS sequential_rows_read
                     , idx_scan           AS index_scan
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
  end

  def self.table_size
    tbl_size_array = select(<<-SQL, "Table Size")
                SELECT relname                                                           AS table_name
                     , to_char(reltuples, '999G999G999G999')                             AS rows
                     , to_char(((relpages * 8.0) / (1024 *1024)), '999G999.999')         AS size_in_gb
                     , to_char(((relpages / (reltuples + 1)) * 8.0 *1024),'999G999.999') AS average_row_size
                  FROM pg_class
                 WHERE reltuples > 1
                   AND relname NOT LIKE 'pg_%'
              ORDER BY reltuples DESC
                     , relpages  DESC ;
                 SQL
  end

  def self.text_table_indexes(table_name)
    return select(<<-SQL, "Text table Indexes")
                    SELECT relname
                      FROM pg_class,
                            ( SELECT reltoastrelid FROM pg_class
                              WHERE relname = '#{table_name}' ) tt
                      WHERE oid = (SELECT reltoastidxid FROM pg_class
                                    WHERE oid = tt.reltoastrelid)
                      ORDER BY 1
                    SQL
  end
end

puts "CLIENT CONNECTIONS\n==========================================================================="
puts Dba.client_connections.tableize(:leading_columns => ['spid'], :trailing_columns => ['query'])
puts "\n\n"

puts "DATABASE STATISTICS\n==========================================================================="
puts Dba.database_statistics.tableize(:leading_columns => ['name'])
puts "\n\n"

puts "TABLE STATISTICS\n==========================================================================="
puts Dba.table_statistics.tableize(:leading_columns => ['table_name'])
puts "\n\n"

puts "TABLE SIZES\n==========================================================================="
puts Dba.table_size.tableize(:leading_columns => ['table_name'])
puts "\n\n"

puts "DATABASE BLOAT\n==========================================================================="
puts Dba.database_bloat.tableize(:leading_columns => ['table_name', 'index_name'])
puts "\n\n"

puts "TABLE BLOAT\n==========================================================================="
puts Dba.table_bloat.tableize(:leading_columns => ['table_name'])
puts "\n\n"

puts "INDEX BLOAT\n==========================================================================="
puts Dba.index_bloat.tableize(:leading_columns => ['table_name', 'index_name'])
