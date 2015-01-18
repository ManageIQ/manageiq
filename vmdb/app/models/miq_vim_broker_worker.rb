class MiqVimBrokerWorker < MiqWorker
  self.required_roles         = %w{
                                    ems_inventory
                                    ems_metrics_collector
                                    ems_operations
                                    smartproxy
                                    smartstate
                                    vmdb_storage_bridge
                                  }
  self.check_for_minimal_role = false
  self.workers                = lambda {
    return 0 unless EmsVmware.use_vim_broker?
    return self.has_minimal_env_option? ? 1 : 0 if MiqServer.minimal_env?
    return 1
  }

  def self.has_required_role?
    return false if emses_to_monitor.empty?
    super
  end

  def self.emses_to_monitor
    EmsVmware.where(:zone_id => MiqServer.my_server.zone_id).includes(:authentications).select(&:authentication_valid?)
  end

  def self.available?
    self.find_current.first
  end

  def self.available_in_zone?(zone = nil)
    zone ||= MiqServer.zone
    zone   = Zone.find_by_name(zone) if zone.kind_of?(String)
    return false if zone.nil?
    self.find_current.any? { |w| w.miq_server && w.miq_server.zone == zone }
  end

  def self.drb_uri
    log_prefix = "MIQ(MiqVimBrokerWorker.drb_uri)"
    broker = self.find_current.first
    if broker.nil?
      $log.warn("#{log_prefix} Active VimBroker not found")
      return nil
    end

    if broker.uri.blank?
      $log.warn("#{log_prefix} Active VimBroker DRb URI is blank")
      return nil
    end

    $log.debug("#{log_prefix} Active VimBroker DRb URI is #{broker.uri}")
    return broker.uri
  end

  def self.drb_port
    log_prefix = "MIQ(MiqVimBrokerWorker.drb_uri)"
    uri = self.drb_uri
    return nil if uri.nil?
    scheme, userinfo, host, port, registry, path, opaque, query, fragment = URI.split(uri)
    $log.debug("#{log_prefix} Active VimBroker DRb Port is #{port}")
    return port.to_i
  end

  def self.broker_unavailable(err_class, message)
    $log.warn("MIQ(MiqVimBrokerWorker) The following error was encountered, '#{message}', the broker server should be restarted on the next heartbeat")
    broker = self.find_current.first
    broker_message = (err_class == "Errno::EMFILE") ? "broker_too_many_files" : "broker_unavailable"
    broker.send_message_to_worker_monitor(broker_message) unless broker.nil?
  end

  def self.queue_reconnect_ems(ems)
    deliver_on = Time.now.utc + (self.worker_settings[:reconnect_retry_interval] || 5.minutes)
    $log.info "MIQ(MiqVimBrokerWorker) Queueing reconnect for EMS name: [#{ems.name}], id: [#{ems.id}] at [#{deliver_on}]"
    MiqQueue.put(
      :class_name  => self.name,
      :method_name => "reconnect_ems",
      :args        => [ems.id],
      :deliver_on  => deliver_on
    )
  end

  def self.reconnect_ems(ems_id)
    broker = self.find_current.first
    broker.send_message_to_worker_monitor('reconnect_ems', ems_id) unless broker.nil?
  end

  def self.miq_vim_broker_class
    @miq_vim_broker_class ||= begin
      require 'VMwareWebService/MiqVim'
      require 'VMwareWebService/MiqVimBroker'
      MiqVimBroker
    end
  end

  def self.cleanup_for_pid(pid)
    log_prefix = "MIQ(MiqVimBrokerWorker.cleanup_for_pid)"
    if self.available?
      $log.info("#{log_prefix} Releasing any broker connections for pid: [#{pid}]")
      broker = self.miq_vim_broker_class.new(:client, self.drb_port)
      broker.releaseSession(pid)
    end
  rescue => err
    $log.info("#{log_prefix} Releasing any broker connections for pid: [#{pid}], ERROR: #{err.message}")
  end

  def friendly_name
    @friendly_name ||= "VMware Session Broker"
  end

end
