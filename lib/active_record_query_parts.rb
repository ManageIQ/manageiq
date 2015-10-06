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

  # Links for the various string length functions:
  #   http://www.postgresql.org/docs/9.1/static/functions-binarystring.html
  #   http://www.postgresql.org/docs/9.1/static/functions-string.html
  #   http://blog.sqlauthority.com/2007/06/20/sql-server-find-length-of-text-field/

  def self.string_length
    "LENGTH"
  end

  def self.text_length
    "LENGTH"
  end

  def self.binary_length
    "LENGTH"
  end

  def self.concat(*args)
    args.join('||')
  end

  def self.regexp(field, regex, qualifier = nil)
    operator = "SIMILAR TO"

    operator = "NOT #{operator}" if qualifier == :negate

    "#{field} #{operator} '#{regex}'"
  end

  def self.not_regexp(field, regex)
    regexp(field, regex, :negate)
  end

  def self.glob_to_sql_like(text)
    text.tr!('*', '%')
    text.tr!('?', '_')
    text
  end
end
