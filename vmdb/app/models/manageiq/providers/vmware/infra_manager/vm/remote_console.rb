module ManageIQ::Providers::Vmware::InfraManager::Vm::RemoteConsole
  require_dependency 'securerandom'

  def console_supported?(type)
    %w(VMRC VNC MKS).include?(type.upcase)
  end

  def validate_remote_console_acquire_ticket(protocol, options = {})
    raise(MiqException::RemoteConsoleNotSupportedError, "#{protocol} remote console requires the vm to be registered with a management system.") if self.ext_management_system.nil?

    options[:check_if_running] = true unless options.has_key?(:check_if_running)
    raise(MiqException::RemoteConsoleNotSupportedError, "#{protocol} remote console requires the vm to be running.") if options[:check_if_running] && self.state != "on"
  end

  def remote_console_acquire_ticket(protocol, proxy_miq_server = nil)
    self.send("remote_console_#{protocol.to_s.downcase}_acquire_ticket", proxy_miq_server)
  end

  def remote_console_acquire_ticket_queue(protocol, userid, proxy_miq_server = nil)
    task_opts = {
      :action       => "acquiring Vm #{self.name} #{protocol.to_s.upcase} remote console ticket for user #{userid}",
      :userid       => userid
    }

    queue_opts = {
      :class_name   => self.class.name,
      :instance_id  => self.id,
      :method_name  => 'remote_console_acquire_ticket',
      :priority     => MiqQueue::HIGH_PRIORITY,
      :role         => 'ems_operations',
      :zone         => self.my_zone,
      :args         => [protocol, proxy_miq_server]
    }

    return MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  #
  # MKS
  #

  def remote_console_mks_acquire_ticket(proxy_miq_server = nil)
    validate_remote_console_acquire_ticket("mks", :check_if_running => false)
    self.ext_management_system.vm_remote_console_mks_acquire_ticket(self)
  end

  #
  # VMRC
  #

  def remote_console_vmrc_acquire_ticket(proxy_miq_server = nil)
    validate_remote_console_acquire_ticket("vmrc")
    self.ext_management_system.remote_console_vmrc_acquire_ticket
  end

  def validate_remote_console_vmrc_support
    validate_remote_console_acquire_ticket("vmrc")
    self.ext_management_system.validate_remote_console_vmrc_support
    true
  end

  #
  # VNC
  #

  def remote_console_vnc_acquire_ticket(proxy_miq_server = nil)
    validate_remote_console_acquire_ticket("vnc")

    if proxy_miq_server
      proxy_miq_server = MiqServer.extract_objects(proxy_miq_server)
      config = proxy_miq_server.get_config.config

      proxy_address = config.fetch_path(:server, :vnc_proxy_address)
      proxy_address = nil if proxy_address.blank?
      proxy_port    = config.fetch_path(:server, :vnc_proxy_port)
      proxy_port    = nil if proxy_port.blank?
      proxy_port    &&= proxy_port.to_i
    else
      proxy_address = proxy_port = nil
    end

    host_address = proxy_address ? self.host.guid : self.host.address
    password     = SecureRandom.base64[0, 8]  # Random password from the Base64 character set

    host_port    = self.host.reserve_next_available_vnc_port

    # Determine if any Vms on this Host already have this port, and if so, disable them
    old_vms = self.host.vms_and_templates.where(:vnc_port => host_port)
    old_vms.each do |old_vm|
      _log.info "Disabling VNC on #{old_vm.class.name} id: [#{old_vm.id}] name: [#{old_vm.name}], since the port is being reused."
      old_vm.with_provider_object do |vim_vm|
        vim_vm.setRemoteDisplayVncAttributes(:enabled => false, :port => nil, :password => nil)
      end
    end
    old_vms.update_all(:vnc_port => nil)

    # Enable on this Vm with the requested port and random password
    _log.info "Enabling VNC on #{self.class.name} id: [#{self.id}] name: [#{self.name}]"
    self.with_provider_object do |vim_vm|
      vim_vm.setRemoteDisplayVncAttributes(:enabled => true, :port => host_port, :password => password)
    end
    self.update_attributes(:vnc_port => host_port)

    return password, host_address, host_port, proxy_address, proxy_port
  end
end
