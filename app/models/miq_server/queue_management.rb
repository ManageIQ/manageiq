module MiqServer::QueueManagement
  extend ActiveSupport::Concern

  def clear_miq_queue_for_this_server
    loop do
      msg = MiqQueue.get(:queue_name => 'miq_server', :zone => my_zone)
      break if msg.nil?

      _log.info("Removing message #{MiqQueue.format_full_log_msg(msg)}")
      msg.destroy
    end
  end

  def process_miq_queue
    loop do
      msg = MiqQueue.get(:queue_name => 'miq_server', :zone => my_zone)
      break if msg.nil?

      status, message, result = msg.deliver(self)

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
  end

  def enqueue_for_server(method_name)
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => id,
      :queue_name  => 'miq_server',
      :zone        => zone.name,
      :method_name => method_name,
      :server_guid => guid
    )
  end

  def shutdown_and_exit_queue
    enqueue_for_server('shutdown_and_exit')
  end

  # Tell the remote or local server to restart
  def restart_queue
    log_message  = "Server restart requested"
    log_message += ", remote server: [#{name}], GUID: [#{guid}], initiated from: [#{MiqServer.my_server.name}], GUID: [#{MiqServer.my_server.guid}]" if self.is_remote?
    _log.info log_message
    enqueue_for_server('restart')
  end

  def ntp_reload_queue
    return unless MiqEnvironment::Command.is_appliance? # matches ntp_reload's guard clause

    MiqQueue.put(
      :class_name  => "MiqServer",
      :instance_id => id,
      :method_name => "ntp_reload",
      :server_guid => guid,
      :priority    => MiqQueue::HIGH_PRIORITY,
      :args => [server_ntp_settings],
      :zone        => my_zone
    )
  end
end
