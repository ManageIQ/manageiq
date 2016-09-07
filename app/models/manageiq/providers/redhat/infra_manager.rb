class ManageIQ::Providers::Redhat::InfraManager < ManageIQ::Providers::InfraManager
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :RefreshWorker
  require_nested :RefreshParser
  require_nested :MetricsCapture
  require_nested :MetricsCollectorWorker
  require_nested :Host
  require_nested :Provision
  require_nested :ProvisionViaIso
  require_nested :ProvisionViaPxe
  require_nested :ProvisionWorkflow
  require_nested :Refresher
  require_nested :Template
  require_nested :Vm

  supports :provisioning

  def self.ems_type
    @ems_type ||= "rhevm".freeze
  end

  def self.description
    @description ||= "Red Hat Enterprise Virtualization Manager".freeze
  end

  def self.default_blacklisted_event_names
    %w(
      UNASSIGNED
      USER_REMOVE_VG
      USER_REMOVE_VG_FAILED
      USER_VDC_LOGIN
      USER_VDC_LOGOUT
      USER_VDC_LOGIN_FAILED
    )
  end

  def self.without_iso_datastores
    includes(:iso_datastore).where(:iso_datastores => {:id => nil})
  end

  def self.any_without_iso_datastores?
    without_iso_datastores.count > 0
  end

  def supports_port?
    true
  end

  def supported_auth_types
    %w(default metrics)
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  # Connect to the engine using version 4 of the API and the `ovirt-engine-sdk` gem.
  def self.raw_connect_v4(server, port, path, username, password, service)
    require 'ovirtsdk4'

    # Get the timeout from the configuration:
    timeout, = ems_timeouts(:ems_redhat, service)

    # Create the connection:
    OvirtSDK4::Connection.new(
      :url      => "https://#{server}:#{port}#{path}",
      :username => username,
      :password => password,
      :timeout  => timeout,
      :insecure => true,
      :log      => $rhevm_log,
    )
  end

  # Connect to the engine using version 3 of the API and the `ovirt` gem.
  def self.raw_connect_v3(server, port, path, username, password, service)
    require 'ovirt'
    require 'ovirt_provider/inventory/ovirt_inventory'

    Ovirt.logger = $rhevm_log

    params = {
      :server     => server,
      :port       => port.presence && port.to_i,
      :path       => path,
      :username   => username,
      :password   => password,
      :verify_ssl => false
    }

    read_timeout, open_timeout = ems_timeouts(:ems_redhat, service)
    params[:timeout]      = read_timeout if read_timeout
    params[:open_timeout] = open_timeout if open_timeout

    const = service == "Inventory" ? OvirtInventory : Ovirt.const_get(service)
    const.new(params)
  end

  def connect(options = {})
    raise "no credentials defined" if self.missing_credentials?(options[:auth_type])

    # If there is API path stored in the endpoints table and use it:
    path = default_endpoint.path
    _log.info("Using stored API path '#{path}'.") unless path.blank?

    server   = options[:ip] || address
    port     = options[:port] || self.port
    username = options[:user] || authentication_userid(options[:auth_type])
    password = options[:pass] || authentication_password(options[:auth_type])
    service  = options[:service] || "Service"
    version  = options[:version] || 3

    # Create the underlying connection according to the version of the oVirt API requested by
    # the caller:
    connect_method = version == 4 ? :raw_connect_v4 : :raw_connect_v3
    connection = self.class.public_send(connect_method, server, port, path, username, password, service)

    # Copy the API path to the endpoints table:
    default_endpoint.path = version == 4 ? '/ovirt-engine/api' : connection.api_path

    connection
  end

  def rhevm_service
    @rhevm_service ||= connect(:service => "Service")
  end

  def rhevm_inventory
    @rhevm_inventory ||= connect(:service => "Inventory")
  end

  def with_provider_connection(options = {})
    raise "no block given" unless block_given?
    _log.info("Connecting through #{self.class.name}: [#{name}]")
    begin
      connection = connect(options)
      yield connection
    ensure
      # The `connect` method will return different types of objects depending on the value of the `version`
      # parameter. If `version` is 3 the connection object is created by the `ovirt` gem and it is closed
      # using the `disconnect` method. If `version` is 4 the object is created by the oVirt Ruby SDK, and
      # it is closed using the `close` method.
      begin
        if connection.respond_to?(:disconnect)
          connection.disconnect
        elsif connection.respond_to?(:close)
          connection.close
        end
      rescue => error
        _log.error("Error while disconnecting #{error}")
        nil
      end
    end
  end

  def verify_credentials_for_rhevm(options = {})
    connect(options).api
  rescue URI::InvalidURIError
    raise "Invalid URI specified for RHEV server."
  rescue SocketError => err
    raise "Error occurred attempted to connect to RHEV server.", err
  rescue => err
    _log.error("Error while verifying credentials #{err}")
    raise MiqException::MiqEVMLoginError, err
  end

  def rhevm_metrics_connect_options(options = {})
    metrics_hostname = connection_configuration_by_role('metrics')
      .try(:endpoint)
      .try(:hostname)
    server   = options[:hostname] || metrics_hostname || hostname
    username = options[:user] || authentication_userid(:metrics)
    password = options[:pass] || authentication_password(:metrics)
    database = options[:database]

    {
      :host     => server,
      :database => database,
      :username => username,
      :password => password
    }
  end

  def verify_credentials_for_rhevm_metrics(options = {})
    require 'ovirt_metrics'
    OvirtMetrics.connect(rhevm_metrics_connect_options(options))
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

    _log.warn("PGError: #{message}")
    raise MiqException::MiqEVMLoginError, message
  rescue Exception => e
    raise MiqException::MiqEVMLoginError, e.to_s
  ensure
    OvirtMetrics.disconnect rescue nil
  end

  def authentications_to_validate
    at = [:default]
    at << :metrics if self.has_authentication_type?(:metrics)
    at
  end

  def verify_credentials(auth_type = nil, options = {})
    auth_type ||= 'default'

    case auth_type.to_s
    when 'default' then verify_credentials_for_rhevm(options)
    when 'metrics' then verify_credentials_for_rhevm_metrics(options)
    else;          raise "Invalid Authentication Type: #{auth_type.inspect}"
    end
  end

  def self.event_monitor_class
    self::EventCatcher
  end

  def self.provision_class(via)
    case via
    when "iso" then self::ProvisionViaIso
    when "pxe" then self::ProvisionViaPxe
    else            self::Provision
    end
  end

  def history_database_name
    @history_database_name ||= begin
      version = version_3_0? ? '3_0' : '>3_0'
      self.class.history_database_name_for(version)
    end
  end

  def self.history_database_name_for(api_version)
    require 'ovirt_metrics'
    case api_version
    when '3_0'
      OvirtMetrics::DEFAULT_HISTORY_DATABASE_NAME_3_0
    else
      OvirtMetrics::DEFAULT_HISTORY_DATABASE_NAME
    end
  end

  def version_3_0?
    if @version_3_0.nil?
      @version_3_0 =
        if api_version.nil?
          with_provider_connection(&:version_3_0?)
        else
          api_version.starts_with?("3.0")
        end
    end

    @version_3_0
  end

  def vm_reconfigure(vm, options = {})
    log_header = "EMS: [#{name}] #{vm.class.name}: id [#{vm.id}], name [#{vm.name}], ems_ref [#{vm.ems_ref}]"
    spec       = options[:spec]

    vm.with_provider_object do |rhevm_vm|
      _log.info("#{log_header} Started...")
      update_vm_memory(rhevm_vm, spec["memoryMB"] * 1.megabyte) if spec["memoryMB"]

      cpu_options = {}
      cpu_options[:cores]   = spec["numCoresPerSocket"] if spec["numCoresPerSocket"]
      cpu_options[:sockets] = spec["numCPUs"] / (cpu_options[:cores] || vm.cpu_cores_per_socket) if spec["numCPUs"]

      rhevm_vm.cpu_topology = cpu_options if cpu_options.present?
    end

    # Removing disks
    remove_disks(spec["disksRemove"], vm) if spec["disksRemove"]

    # Adding disks
    add_disks(spec["disksAdd"], vm) if spec["disksAdd"]

    _log.info("#{log_header} Completed.")
  end

  def add_disks(add_disks_spec, vm)
    ems_storage_uid = add_disks_spec["ems_storage_uid"]
    with_disk_attachments_service(vm) do |service|
      add_disks_spec["disks"].each { |disk_spec| service.add(prepare_disk(disk_spec, ems_storage_uid)) }
    end
  end

  def prepare_disk(disk_spec, ems_storage_uid)
    {
      :bootable  => disk_spec["bootable"],
      :interface => "VIRTIO",
      :disk      => {
        :provisioned_size => disk_spec["disk_size_in_mb"].to_i * 1024 * 1024,
        :sparse           => disk_spec["thin_provisioned"],
        :format           => disk_spec["format"],
        :storage_domain   => {:id => ems_storage_uid}
      }
    }
  end

  # RHEVM requires that the memory of the VM will be bigger or equal to the reserved memory at any given time.
  # Therefore, increasing the memory of the vm should precede to updating the reserved memory, and the opposite:
  # Decreasing the memory to a lower value than the reserved memory requires first to update the reserved memory
  def update_vm_memory(rhevm_vm, memory)
    if memory > rhevm_vm.attributes.fetch_path(:memory)
      rhevm_vm.memory = memory
      rhevm_vm.memory_reserve = memory
    else
      rhevm_vm.memory_reserve = memory
      rhevm_vm.memory = memory
    end
  end

  def remove_disks(disks, vm)
    with_disk_attachments_service(vm) do |service|
      disks.each { |disk_id| service.attachment_service(disk_id).remove }
    end
  end

  # Adding disks is supported only by API version 4.0
  def with_disk_attachments_service(vm)
    connection = connect(:version => 4)
    service = connection.system_service.vms_service.vm_service(vm.uid_ems).disk_attachments_service
    yield service
  ensure
    connection.close
  end

  # Calculates an "ems_ref" from the "href" attribute provided by the oVirt REST API, removing the
  # "/ovirt-engine/" prefix, as for historic reasons the "ems_ref" stored in the database does not
  # contain it, it only contains the "/api" prefix which was used by older versions of the engine.
  def self.make_ems_ref(href)
    href && href.sub(%r{^/ovirt-engine/}, '/')
  end

  def self.extract_ems_ref_id(href)
    href && href.split("/").last
  end
end
