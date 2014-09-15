$:.push(File.expand_path(File.join(Rails.root, %w{.. lib kvm} )))

class EmsKvm < EmsInfra
  def self.ems_type
    @ems_type ||= "kvm".freeze
  end

  def self.description
    @description ||= "KVM".freeze
  end


  def verify_credentials(auth_type=nil, options={})
    raise MiqException::MiqHostError, "No credentials defined" if self.authentication_invalid?(auth_type)
    ip   = options[:ip]   || self.ipaddress
    user = options[:user] || self.authentication_userid(auth_type)
    pass = options[:pass] || self.authentication_password(auth_type)

    require 'MiqSshUtil'
    begin
      $log.info "MIQ(host-verify_credentials): A user '#{user}' provided credentials for a hostname '#{self.hostname}', host ip '#{ip}'"
      ssu = MiqSshUtil.new(ip, user, pass, options)
      ssu.exec("uname -a")
    rescue Net::SSH::AuthenticationFailed
      raise MiqException::MiqHostError, "Login failed due to a bad username or password."
    rescue Exception
      raise MiqException::MiqHostError, "Unexpected response returned from system, see log for details"
    end

    return true
  end

  def with_provider_connection(options = {})
    raise "no block given" unless block_given?
    log_header = "MIQ(#{self.class.name}.with_provider_connection)"
    $log.info("#{log_header} Connecting through #{self.class.name}: [#{self.name}]")
    ip   = options[:ip]   || self.ipaddress
    user = options[:user] || self.authentication_userid(options[:auth_type])
    pass = options[:pass] || self.authentication_password(options[:auth_type])
    begin
      require 'MiqKvmHost'
      kvm = MiqKvmHost.new(ip, user, pass)
      kvm.connect
      yield kvm
    ensure
      kvm.disconnect if kvm rescue nil
    end
  end

  def vm_power_operation(vm, op)
    with_provider_connection do |kvm|
      begin
        vm_handle = kvm.getVm(vm.uid_ems)
        vm_handle.send(op)
        vm.state = vm_handle.powerState
        vm.save
      rescue => err
        $log.error "MIQ(EmsKvm.vm_power_operation) vm=[#{vm.name}], op=[#{op}], error: #{err}"
      end
    end
  end

  def vm_start(vm)
    vm_power_operation(vm, :start)
  end

  def vm_stop(vm)
    vm_power_operation(vm, :stop)
  end

  def vm_suspend(vm)
    vm_power_operation(vm, :suspend)
  end

  def vm_pause(vm)
    vm_power_operation(vm, :pause)
  end
end
