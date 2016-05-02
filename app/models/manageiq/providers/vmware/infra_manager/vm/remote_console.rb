module ManageIQ::Providers::Vmware::InfraManager::Vm::RemoteConsole
  require_dependency 'securerandom'

  def console_supported?(type)
    %w(VMRC VNC MKS).include?(type.upcase)
  end

  def validate_remote_console_acquire_ticket(protocol, options = {})
    raise(MiqException::RemoteConsoleNotSupportedError, "#{protocol} remote console requires the vm to be registered with a management system.") if ext_management_system.nil?

    options[:check_if_running] = true unless options.key?(:check_if_running)
    raise(MiqException::RemoteConsoleNotSupportedError, "#{protocol} remote console requires the vm to be running.") if options[:check_if_running] && state != "on"
  end

  def remote_console_acquire_ticket(userid, protocol)
    send("remote_console_#{protocol.to_s.downcase}_acquire_ticket", userid)
  end

  def remote_console_acquire_ticket_queue(protocol, userid)
    task_opts = {
      :action => "acquiring Vm #{name} #{protocol.to_s.upcase} remote console ticket for user #{userid}",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'remote_console_acquire_ticket',
      :priority    => MiqQueue::HIGH_PRIORITY,
      :role        => 'ems_operations',
      :zone        => my_zone,
      :args        => [userid, protocol]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  #
  # MKS
  #

  def remote_console_mks_acquire_ticket
    validate_remote_console_acquire_ticket("mks", :check_if_running => false)
    ext_management_system.vm_remote_console_mks_acquire_ticket(self)
  end

  #
  # VMRC
  #

  def remote_console_vmrc_acquire_ticket(_userid = nil)
    validate_remote_console_acquire_ticket("vmrc")
    ext_management_system.remote_console_vmrc_acquire_ticket
  end

  def validate_remote_console_vmrc_support
    validate_remote_console_acquire_ticket("vmrc")
    ext_management_system.validate_remote_console_vmrc_support
    true
  end

  #
  # VNC
  #
  def remote_console_html5_acquire_ticket(userid)
    remote_console_vnc_acquire_ticket(userid)
  end

  def remote_console_vnc_acquire_ticket(userid)
    validate_remote_console_acquire_ticket("vnc")

    password     = SecureRandom.base64[0, 8] # Random password from the Base64 character set
    host_port    = host.reserve_next_available_vnc_port

    # Determine if any Vms on this Host already have this port, and if so, disable them
    old_vms = host.vms_and_templates.where(:vnc_port => host_port)
    old_vms.each do |old_vm|
      _log.info "Disabling VNC on #{old_vm.class.name} id: [#{old_vm.id}] name: [#{old_vm.name}], since the port is being reused."
      old_vm.with_provider_object do |vim_vm|
        vim_vm.setRemoteDisplayVncAttributes(:enabled => false, :port => nil, :password => nil)
      end
    end
    old_vms.update_all(:vnc_port => nil)

    # Enable on this Vm with the requested port and random password
    _log.info "Enabling VNC on #{self.class.name} id: [#{id}] name: [#{name}]"
    with_provider_object do |vim_vm|
      vim_vm.setRemoteDisplayVncAttributes(:enabled => true, :port => host_port, :password => password)
    end
    update_attributes(:vnc_port => host_port)

    SystemConsole.where(:vm_id => id).each(&:destroy)
    SystemConsole.create!(
      :user       => User.find_by(:userid => userid),
      :vm_id      => id,
      :host_name  => host.address,
      :port       => host_port,
      :ssl        => false,
      :protocol   => 'vnc',
      :secret     => password,
      :url_secret => SecureRandom.hex
    ).connection_params
  end
end
