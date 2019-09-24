module ActiveRecordQueryParts
  # Acquires a pure exclusive lock on a row so no other queries can access it.
  def self.exclusive_row_lock
    " FOR UPDATE"
  end

  # Acquires a pseudo exclusive lock that blocks other selects trying to
  # acquire the same lock, however, selects not requesting the lock can still
  # read.
  def self.update_row_lock
    " FOR UPDATE"
  end

  # Acquires a lock that allows any other selects to obtain the lock and read,
  # but which will be escalated to an update lock when the row is updated
  # within that transaction.
  def self.shared_row_lock
    " FOR SHARE"
  end

  def self.glob_to_sql_like(text)
    text.tr!('*?', '%_')
    text
  end
end
