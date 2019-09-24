module ArLock
  # Creates a critical section around the specified block, in the style of
  # Mutex#synchronize, by locking on the database record in SQL.
  #
  # See ActiveRecord::Locking::Pessimistic#with_lock for details about
  #   the original version of this method.
  #
  # mode::    :exclusive or :shared (or :EX or :SH).  Default is :exclusive.
  #           :exclusive mode will prevent two database callers from entering
  #             the block concurrently.
  #           :shared mode will allow concurrent entry into the block, but will
  #             escalate to an :exclusive lock when ActiveRecord issues an
  #             update to the record.
  # timeout:: The amount of time, in seconds, before the block is timed out.
  #             This prevents the block from blocking others indefinitely.
  #             Default is 60 seconds.
  def lock(mode = :exclusive, timeout = 60.seconds)
    lock = case mode
           when :shared,    :SH then ActiveRecordQueryParts.shared_row_lock
           when :exclusive, :EX then ActiveRecordQueryParts.update_row_lock
           else raise "unknown lock mode <#{mode.inspect}>"
           end

    transaction do
      _log.debug("Acquiring lock on #{self.class.name}::#{id}...")
      lock!(lock)
      _log.debug("Acquired lock")

      begin
        Timeout.timeout(timeout) { yield self }
      ensure
        _log.debug("Releasing lock")
      end
    end
  end
end
