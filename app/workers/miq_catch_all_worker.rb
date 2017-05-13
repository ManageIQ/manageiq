class MiqCatchAllWorker
  include Vmdb::Logging
  include Sidekiq::Worker

  def perform(options = {})

    _log.info("DEBUG_PEFORM: options(#{options.inspect})")
    options = HashWithIndifferentAccess.new(options)
    msg = MiqQueue.new(options)
    status, message, result = msg.deliver(requestor)
    puts "status: message(#{message}), status(#{status})"

    if status == "timeout"
      begin
        _log.info("Reconnecting to DB after timeout error during queue deliver")
        ActiveRecord::Base.connection.reconnect!
      rescue => err
        _log.error("Error encountered during <ActiveRecord::Base.connection.reconnect!> error:#{err.class.name}: #{err.message}")
      end
    end

    msg.delivered(status, message, result) unless status == 'retry'
  end

  def requestor
    server = MiqServer.my_server
    return server if server
    _log.info("MiqServer#my_server not found, use seed instead")
    server =  MiqServer.seed
    return server if server
    _log.info("MiqServer#seed returns nil?")
  end
end
