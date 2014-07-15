# Derived from code found in http://stackoverflow.com/questions/5490411/counting-the-number-of-queries-performed

class QueryCounter
  def self.count(&block)
    new.count(&block)
  end

  IGNORED_STATEMENTS = %w(CACHE SCHEMA)

  def callback(_name, _start, _finish, _id, payload)
    @count += 1 unless IGNORED_STATEMENTS.include?(payload[:name])
  end

  def callback_proc
    lambda(&method(:callback))
  end

  def count(&block)
    @count = 0
    ActiveSupport::Notifications.subscribed(callback_proc, 'sql.active_record', &block)
    @count
  end
end
