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



# TODO:  Remove everything below this comment once the following is released in
# Rails: https://github.com/rails/rails/commit/2b5d139

# Yes, I realize this was opened up above... this is just to make it easier to
# delete.
#
# Also, FYI, enable_query_cache! is not the same as what is defined below, but
# something that already exists in this class.
ActiveRecord::ConnectionAdapters::AbstractAdapter.class_eval do
  set_callback(:checkout, :after, :configure_query_cache!)

  def configure_query_cache!
    enable_query_cache! if pool.query_cache_enabled
  end
end

module MiqConnectionPoolConfiguration
  def initialize(*)
    super
    @query_cache_enabled = Concurrent::Map.new { false }
  end

  def enable_query_cache!
    @query_cache_enabled[connection_cache_key(Thread.current)] = true
    connection.enable_query_cache! if active_connection?
  end

  def disable_query_cache!
    @query_cache_enabled.delete connection_cache_key(Thread.current)
    connection.disable_query_cache! if active_connection?
  end

  def query_cache_enabled
    @query_cache_enabled[connection_cache_key(Thread.current)]
  end
end

ActiveRecord::ConnectionAdapters::ConnectionPool.class_eval do
  include MiqConnectionPoolConfiguration
end

# In the aforementioned commit, this is added to
# `ActiveRecord::QueryCache::ClassMethods`, but that is only included in
# `ActiveRecord::Base`.  Adding this directly to Base avoids load dependency
# issues (hopefully).
ActiveRecord::Base.class_eval do
  def self.run
    connection_id = ActiveRecord::Base.connection_id

    caching_pool = ActiveRecord::Base.connection_pool
    caching_was_enabled = caching_pool.query_cache_enabled

    caching_pool.enable_query_cache!

    [caching_pool, caching_was_enabled, connection_id]
  end

  def self.complete((caching_pool, caching_was_enabled, connection_id))
    ActiveRecord::Base.connection_id = connection_id

    caching_pool.disable_query_cache! unless caching_was_enabled

    ActiveRecord::Base.connection_handler.connection_pool_list.each do |pool|
      pool.release_connection if pool.active_connection? && !pool.connection.transaction_open?
    end
  end
end
