ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
  set_callback(:checkout, :after, :log_after_checkout)
  set_callback(:checkin,  :after, :log_after_checkin)

  def connection_info_for_logging
    pool             = ActiveRecord::Base.connection_pool
    pool_size        = pool.size
    count            = pool.connections.count
    in_use           = pool.connections.count(&:in_use?)
    waiting_in_queue = pool.num_waiting_in_queue

    "connection_pool: size: #{pool_size}, connections: #{count}, in use: #{in_use}, waiting_in_queue: #{waiting_in_queue}"
  end

  def log_after_checkin
    logger.debug { "#{self.class.name.demodulize}##{__method__}, #{connection_info_for_logging}" } if logger && ActiveRecord::Base.connected?
  end

  def log_after_checkout
    logger.debug { "#{self.class.name.demodulize}##{__method__}, #{connection_info_for_logging}" } if logger && ActiveRecord::Base.connected?
  end
end
