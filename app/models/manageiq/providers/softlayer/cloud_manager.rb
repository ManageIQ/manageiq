class ManageIQ::Providers::SoftLayer::CloudManager < ManageIQ::Providers::CloudManager
  require_nested :EventParser
  require_nested :Flavor
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :Template
  require_nested :Vm

  def self.ems_type
    @ems_type ||= "softlayer".freeze
  end

  def self.description
    @description ||= "IBM SoftLayer".freeze
  end

  def self.hostname_required?
    false
  end

  def self.region_required?
    false
  end

  def supported_auth_types
    %w(
      auth_key
    )
  end

  def missing_credentials?(_type = {})
    false
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  validates :provider_region, :inclusion => {:in => ManageIQ::Providers::SoftLayer::Regions.names}

  def description
    ManageIQ::Providers::SoftLayer::Regions.find_by_name(provider_region)[:description]
  end

  def verify_credentials(auth_type = nil, options = {})
    begin
      options[:auth_type] = auth_type

      connection = connect(options)
    rescue => err
      raise MiqException::MiqInvalidCredentialsError, err.message
    end

    true
  end

  #
  # Connections
  #

  def self.raw_connect(softlayer_username, soflayer_api_key)
    require 'fog/softlayer'

    ::Fog::Compute.new(
      :provider           => "softlayer",
      :softlayer_username => softlayer_username,
      :softlayer_api_key  => soflayer_api_key
    )
  end

  def connect(options = {})
    require 'fog/softlayer'

    raise MiqException::MiqHostError, "No credentials defined" if missing_credentials?(options[:auth_type])

    auth_token = authentication_token(options[:auth_type])
    self.class.raw_connect(project, auth_token)
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
