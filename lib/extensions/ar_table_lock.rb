module ArTableLock
  # Creates mutex by locking on a database table in SQL.
  # Please use record level locking over this
  #
  # passing in mode has been disabled due to brakeman
  #
  # if a different mode is desired, we'll work around issue later
  #
  # possible modes:
  # "ACCESS SHARE", "ROW SHARE", "ROW EXCLUSIVE", "SHARE", "EXCLUSIVE",
  #  "SHARE UPDATE EXCLUSIVE", "SHARE ROW EXCLUSIVE", "ACCESS EXCLUSIVE"
  #
  # details on locks can be found on postgres docs:
  #   can be fount http://www.postgresql.org/docs/9.4/static/explicit-locking.html
  #
  def with_lock
    mode = "SHARE ROW EXCLUSIVE"
    transaction do
      connection.execute("LOCK TABLE #{table_name} in #{mode} MODE")
      yield
    end
  end
end

ActiveRecord::Base.send(:extend, ArTableLock)
