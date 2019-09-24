module ArTableLock
  # Creates mutex by locking on a database table in SQL.
  # Please use record level locking over this
  #
  #   "SHARE ROW EXCLUSIVE"
  #     This mode protects a table against concurrent data changes.
  #     It is self-exclusive so that only one session can hold it at a time.
  #
  # details on locks can be found on postgres docs:
  #   http://www.postgresql.org/docs/9.5/static/explicit-locking.html
  #
  def with_lock(timeout = 60.seconds)
    lock = "SHARE ROW EXCLUSIVE"

    transaction do
      _log.debug("Acquiring lock on #{name} (table: #{table_name}...")
      connection.execute("LOCK TABLE #{table_name} in #{lock} MODE")
      _log.debug("Acquired lock on #{name} (table: #{table_name}...")

      begin
        Timeout.timeout(timeout) { yield }
      ensure
        _log.debug("Releasing lock on #{name} (table: #{table_name}...")
      end
    end
  end
end
