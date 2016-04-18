class ManageIQ::Providers::SoftLayer::CloudManager < ManageIQ::Providers::CloudManager
  require_nested :AvailabilityZone
  require_nested :EventParser
  require_nested :Flavor
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :Template
  require_nested :Vm
  require_nested :Provision
  require_nested :ProvisionWorkflow
  require_nested :OrchestrationStack
  require_nested :OrchestrationServiceOptionConverter
  require_nested :SecurityGroup

  def self.ems_type
    @ems_type ||= "softlayer".freeze
  end

  def self.description
    @description ||= "SoftLayer".freeze
  end

  def self.hostname_required?
    false
  end

  def description
    ManageIQ::Providers::SoftLayer::Regions.find_by_name(provider_region)[:description]
  end

  # Connection

  def self.raw_connect(softlayer_username, soflayer_api_key, options)
    require 'fog/softlayer'

    config = {
      :provider           => "softlayer",
      :softlayer_username => softlayer_username,
      :softlayer_api_key  => soflayer_api_key
    }

    case options[:service]
    when 'compute', nil
      ::Fog::Compute.new(config)
    when 'network'
      ::Fog::Network.new(config)
    when 'dns'
      ::Fog::DNS.new(config)
    when 'storage'
      ::Fog::Storage.new(config)
    when 'account'
      ::Fog::Account.new(config)
    else
      raise ArgumentError, "Unknown service: #{options[:service]}"
    end
  end

  def connect(options = {})
    require 'fog/softlayer'

    raise MiqException::MiqHostError, "No credentials defined" if missing_credentials?(options[:auth_type])

    client_id = options[:user] || authentication_userid(options[:auth_type])
    client_key = options[:api_key] || authentication_key(options[:auth_type])

    self.class.raw_connect(client_id, client_key, options)
  end

  def verify_credentials(_auth_type = nil, options = {})
    connect(options)

    # Hit the SoftLayer servers to make sure authentication has
    # been procced
    connection.regions.all
  rescue Excon::Errors::Unauthorized => err
    raise MiqException::MiqInvalidCredentialsError, err.message

    true
  end

  # Operations

  def vm_start(vm, _options = {})
    vm.start
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_stop(vm, _options = {})
    vm.stop
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_destroy(vm, _options = {})
    vm.destroy
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_reboot(vm, _options = {})
    vm.reboot
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end
end
