module MiqServer::QueueManagement
  extend ActiveSupport::Concern

  def clear_miq_queue_for_this_server
    log_prefix = "MIQ(MiqServer#clear_miq_queue_for_this_server)"

    loop do
      msg = MiqQueue.get(:queue_name => 'miq_server', :zone => self.my_zone)
      break if msg.nil?

      $log.info("#{log_prefix} Removing message #{MiqQueue.format_full_log_msg(msg)}") if $log
      msg.destroy
    end
  end

  def process_miq_queue
    log_prefix = "MIQ(MiqServer#process_miq_queue)"

    loop do
      msg = MiqQueue.get(:queue_name => 'miq_server', :zone => self.my_zone)
      break if msg.nil?

      status, message, result = msg.deliver(self)

      if status == "timeout"
        begin
          $log.info("#{log_prefix} Reconnecting to DB after timeout error during queue deliver") if $log
          ActiveRecord::Base.connection.reconnect!
        rescue => err
          $log.error("#{log_prefix} Error encountered during <ActiveRecord::Base.connection.reconnect!> error:#{err.class.name}: #{err.message}")
        end
      end

      msg.delivered(status, message, result) unless status == 'retry'
    end
  end

  def enqueue_for_server(method_name)
    MiqQueue.put_unless_exists(
      :class_name  => self.class.name,
      :instance_id => self.id,
      :queue_name  => 'miq_server',
      :zone        => self.zone.name,
      :method_name => method_name,
      :server_guid => self.guid
    )
  end

  def shutdown_and_exit_queue
    self.enqueue_for_server('shutdown_and_exit')
  end

  # Tell the remote or local server to restart
  def restart_queue
    log_message  = "MIQ(MiqServer#restart_queue) Server restart requested"
    log_message += ", remote server: [#{self.name}], GUID: [#{self.guid}], initiated from: [#{MiqServer.my_server.name}], GUID: [#{MiqServer.my_server.guid}]" if self.is_remote?
    $log.info log_message
    self.enqueue_for_server('restart')
  end

  def ntp_reload_queue
    MiqQueue.put_or_update(
        :class_name => "MiqServer",
        :instance_id => self.id,
        :method_name => "ntp_reload",
        :server_guid => self.guid,
        :zone => self.my_zone
    ) do |msg, item|
      $log.info("MIQ(MiqServer#ntp_reload_queue) Previous ntp_reload is still running, skipping...Resource: [#{self.class.name}], id: [#{self.id}]") unless msg.nil?
      item.merge(:priority => MiqQueue::HIGH_PRIORITY, :args => [server_ntp_settings])
    end
  end
end
