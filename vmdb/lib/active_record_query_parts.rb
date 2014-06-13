module ActiveRecordQueryParts
  # Acquires a pure exclusive lock on a row so no other queries can access it.
  def self.exclusive_row_lock
    return case ActiveRecord::Base.connection.adapter_name
    when "PostgreSQL", "MySQL" then " FOR UPDATE"  # NOTE: There is no pure exclusive lock in these databases
    else true
    end
  end

  # Acquires a pseudo exclusive lock that blocks other selects trying to
  # acquire the same lock, however, selects not requesting the lock can still
  # read.
  def self.update_row_lock
    return case ActiveRecord::Base.connection.adapter_name
    when "PostgreSQL", "MySQL" then " FOR UPDATE"
    else true
    end
  end

  # Acquires a lock that allows any other selects to obtain the lock and read,
  # but which will be escalated to an update lock when the row is updated
  # within that transaction.
  def self.shared_row_lock
    return case ActiveRecord::Base.connection.adapter_name
    when "PostgreSQL" then " FOR SHARE"
    when "MySQL"      then " LOCK IN SHARE MODE"
    else true
    end
  end

  # Links for the various string length functions:
  #   http://www.postgresql.org/docs/9.1/static/functions-binarystring.html
  #   http://www.postgresql.org/docs/9.1/static/functions-string.html
  #   http://blog.sqlauthority.com/2007/06/20/sql-server-find-length-of-text-field/

  def self.string_length
    return case ActiveRecord::Base.connection.adapter_name
    when "PostgreSQL", "MySQL" then "LENGTH"
    else "LENGTH"
    end
  end

  def self.text_length
    return case ActiveRecord::Base.connection.adapter_name
    when "PostgreSQL", "MySQL" then "LENGTH"
    else "LENGTH"
    end
  end

  def self.binary_length
    return case ActiveRecord::Base.connection.adapter_name
    when "PostgreSQL", "MySQL" then "LENGTH"
    else "LENGTH"
    end
  end

  def self.concat(*args)
    return case ActiveRecord::Base.connection.adapter_name
    when "PostgreSQL"          then args.join('||')
    when "MySQL"               then "CONCAT(#{args.join(',')})"
    else args.join('||')
    end
  end

  def self.glob_to_sql_like(text)
    text.gsub!('*', '%')
    text.gsub!('?', '_')
    text
  end
end
