module ArTableLock
  # Creates mutex by locking on a database table in SQL.
  # Please use record level locking over this
  #
  # default mode: share_row_exclusive
  # possible modes:
  #   :share_update_exclusive, :SUE "SHARE UPDATE EXCLUSIVE"
  #     This mode protects a table against concurrent schema changes and VACUUM runs.
  #   :share_row_exclusive,    :SRU "SHARE ROW EXCLUSIVE"
  #     This mode protects a table against concurrent data changes.
  #     It is self-exclusive so that only one session can hold it at a time.
  # "ACCESS SHARE", "ROW SHARE", "ROW EXCLUSIVE", "SHARE", "EXCLUSIVE",
  #  "SHARE UPDATE EXCLUSIVE", "SHARE ROW EXCLUSIVE", "ACCESS EXCLUSIVE"
  #
  # details on locks can be found on postgres docs:
  #   can be fount http://www.postgresql.org/docs/9.4/static/explicit-locking.html
  #
  def with_lock(mode = :share_row_exclusive, timeout = 60.seconds)
    lock = case mode
           when :share_update_exclusive, :SUE then "SHARE UPDATE EXCLUSIVE"
           when :share_row_exclusive,    :SRU then "SHARE ROW EXCLUSIVE"
           else raise "unknown lock mode <#{mode.inspect}>"
           end

    transaction do
      _log.debug "Acquiring lock on #{name} (table: #{table_name}..."
      connection.execute("LOCK TABLE #{table_name} in #{lock} MODE")
      _log.debug "Acquired lock on #{name} (table: #{table_name}..."

      begin
        Timeout.timeout(timeout) { yield }
      ensure
        _log.debug "Releasing lock on #{name} (table: #{table_name}..."
      end
    end
  end
end

ActiveRecord::Base.send(:extend, ArTableLock)
