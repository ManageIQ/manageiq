ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.class_eval do
  include Vmdb::Logging

  def kill(pid)
    pid_numeric = pid.to_i
    return if pid_numeric == 0
    return if pid_numeric == @spid

    data = select(<<-SQL, "Client Connections")
                      SELECT pid                                     AS spid,
                             current_query                           AS query,
                             age(now(),pg_stat_activity.query_start) AS age
                        FROM pg_stat_activity
                       WHERE pid     = #{pid_numeric}
                         AND datname = #{quote(current_database)}
                      SQL

    item = data.first
    if item.nil?
      _log.info("SPID=[#{pid_numeric}] not found")
    else
      _log.info("Sending CANCEL Request for SPID=[#{pid_numeric}], age=[#{item['age']}], query=[#{item['query']}]")
      result = select(<<-SQL, "Cancel SPID")
                            SELECT pg_cancel_backend(#{pid_numeric})
                            FROM   pg_stat_activity
                            WHERE  datname = #{quote(current_database)}
                         SQL
      result
    end
  end
end
