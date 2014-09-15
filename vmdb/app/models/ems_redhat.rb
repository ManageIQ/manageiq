class EmsRedhat < EmsInfra
  def self.ems_type
    @ems_type ||= "rhevm".freeze
  end

  def self.description
    @description ||= "Red Hat Enterprise Virtualization Manager".freeze
  end

  def self.raw_connect(server, port, username, password, service = "Service")
    require 'RedHatEnterpriseVirtualizationManagerAPI/rhevm_api'
    params = {
      :server   => server,
      :port     => port,
      :username => username,
      :password => password
    }

    read_timeout, open_timeout = ems_timeouts(:ems_redhat, service)
    params[:timeout]      = read_timeout if read_timeout
    params[:open_timeout] = open_timeout if open_timeout

    service = "Rhevm#{service}"
    Object.const_get(service).new(params)
  end

  def connect(options = {})
    raise "no credentials defined" if self.authentication_invalid?(options[:auth_type])

    server   = options[:ip]      || self.address
    port     = options[:port]    || self.port
    username = options[:user]    || self.authentication_userid(options[:auth_type])
    password = options[:pass]    || self.authentication_password(options[:auth_type])
    service  = options[:service] || "Service"

    self.class.raw_connect(server, port, username, password, service)
  end

  def rhevm_service
    @rhevm_service ||= connect(:service => "Service")
  end

  def rhevm_inventory
    @rhevm_inventory ||= connect(:service => "Inventory")
  end

  def with_provider_connection(options = {})
    raise "no block given" unless block_given?
    log_header = "MIQ(#{self.class.name}.with_provider_connection)"
    $log.info("#{log_header} Connecting through #{self.class.name}: [#{self.name}]")
    begin
      connection = self.connect(options)
      yield connection
    ensure
      connection.disconnect if connection rescue nil
    end
  end

  def verify_credentials_for_rhevm(options={})
    server   = options[:ip]   || self.ipaddress
    port     = options[:port] || self.port
    username = options[:user] || self.authentication_userid(:default)
    password = options[:pass] || self.authentication_password(:default)

    begin
      require 'RedHatEnterpriseVirtualizationManagerAPI/rhevm_api'
      rhevm = RhevmInventory.new(
                    :server   => server,
                    :port     => port,
                    :username => username,
                    :password => password)
      raise "Invalid RHEV server ip address specified." if rhevm.api.nil?
    rescue => err
      err = err.to_s.split('<html>').first.strip.chomp(':')
      raise MiqException::MiqEVMLoginError, err
    end

    return true
  end

  def verify_credentials_for_rhevm_metrics(options={})
    log_header = "MIQ(#{self.class.name}.verify_credentials_for_rhevm_metrics)"

    server   = options[:ip]   || self.ipaddress
    username = options[:user] || self.authentication_userid(:metrics)
    password = options[:pass] || self.authentication_password(:metrics)
    database = options[:database]

    conn_info = {
      :host     => server,
      :database => database,
      :username => username,
      :password => password
    }

    begin
      require 'ovirt_metrics'
      OvirtMetrics.connect(conn_info)
      OvirtMetrics.connected?
    rescue PGError => e
      message = (e.message.starts_with?("FATAL:") ? e.message[6..-1] : e.message).strip

      case message
      when /database \".*\" does not exist/
        if database.nil? && (conn_info[:database] != OvirtMetrics::DEFAULT_HISTORY_DATABASE_NAME_3_0)
          conn_info[:database] = OvirtMetrics::DEFAULT_HISTORY_DATABASE_NAME_3_0
          retry
        end
      end

      $log.warn("#{log_header} PGError: #{message}")
      raise MiqException::MiqEVMLoginError, message
    rescue Exception => e
      raise MiqException::MiqEVMLoginError, e.to_s
    ensure
      OvirtMetrics.disconnect rescue nil
    end
  end

  def authentications_to_validate
    at = [:default]
    at << :metrics if self.has_authentication_type?(:metrics)
    at
  end

  def verify_credentials(auth_type=nil, options={})
    auth_type ||= 'default'

    case auth_type.to_s
    when 'default'; verify_credentials_for_rhevm(options)
    when 'metrics'; verify_credentials_for_rhevm_metrics(options)
    else;          raise "Invalid Authentication Type: #{auth_type.inspect}"
    end
  end

  def self.event_monitor_class
    MiqEventCatcherRedhat
  end

  def history_database_name
    @history_database_name ||= begin
      require 'ovirt_metrics'
      version_3_0? ? OvirtMetrics::DEFAULT_HISTORY_DATABASE_NAME_3_0 : OvirtMetrics::DEFAULT_HISTORY_DATABASE_NAME
    end
  end

  def version_3_0?
    if @version_3_0.nil?
      @version_3_0 =
        if self.api_version.nil?
          self.with_provider_connection { |rhevm| rhevm.version_3_0? }
        else
          self.api_version.starts_with?("3.0")
        end
    end

    @version_3_0
  end

  # Helper method for VM scanning
  def storage_mounts_for_vm(vm, job_id=nil)
    return nil unless vm.storage && vm.storage.store_type == "NFS"

    datacenter = vm.parent_datacenter
    raise "VM <#{vm.name}> is not attached to a Data-center" if datacenter.blank?

    base_path = File.join('/mnt', 'vm', job_id)
    base_rhevm_path = File.join(base_path, 'rhev', 'data-center')
    mnt_path  = File.join(base_rhevm_path, 'mnt')
    link_path = File.join(base_rhevm_path, datacenter.uid_ems)

    # Find the storages we need to mount to access this VM
    storages = [vm.storage, vm.storage.hosts.first.storages.detect {|s| s.master?}].uniq.compact

    result = {:mount_points => [], :symlinks => [], :base_dir => base_path, :link_path => link_path}
    storages.each do |s|
      uri = s.location.gsub('//', ':/').strip
      s_mnt_path = File.join(mnt_path, uri.gsub('/', '_'))
      result[:mount_points] << mount_parms = {:uri=>"nfs://#{uri}", :mount_point=>s_mnt_path}

      storage_guid = s.ems_ref.split('/').last
      link_name = File.join(link_path, storage_guid)
      link_mnt_path = File.join(mount_parms[:mount_point], storage_guid)

      # Determine what symlinks we need to make
      result[:symlinks] << {:source=>link_mnt_path, :target=>link_name}
      result[:symlinks] << {:source=>link_mnt_path, :target=>File.join(link_path, 'mastersd')} if s.master?
    end

    return result
  end
end
