class ManageIQ::Providers::Amazon::CloudManager < ManageIQ::Providers::CloudManager
  require_nested :AuthKeyPair
  require_nested :AvailabilityZone
  require_nested :CloudVolume
  require_nested :CloudVolumeSnapshot
  require_nested :EventCatcher
  require_nested :EventParser
  require_nested :Flavor
  require_nested :FloatingIp
  require_nested :MetricsCapture
  require_nested :MetricsCollectorWorker
  require_nested :OrchestrationServiceOptionConverter
  require_nested :OrchestrationStack
  require_nested :Provision
  require_nested :ProvisionWorkflow
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher
  require_nested :SecurityGroup
  require_nested :Template
  require_nested :Vm

  def self.ems_type
    @ems_type ||= "ec2".freeze
  end

  def self.description
    @description ||= "Amazon EC2".freeze
  end

  def self.hostname_required?
    false
  end

  def self.default_blacklisted_event_names
    %w(
      ConfigurationSnapshotDeliveryCompleted
      ConfigurationSnapshotDeliveryStarted
      ConfigurationSnapshotDeliveryFailed
    )
  end

  validates :provider_region, :inclusion => {:in => ManageIQ::Providers::Amazon::Regions.names}

  def description
    ManageIQ::Providers::Amazon::Regions.find_by_name(provider_region)[:description]
  end

  #
  # Connections
  #

  def self.raw_connect(access_key_id, secret_access_key, service, region = nil, proxy_uri = nil)
    service ||= "EC2"
    proxy_uri ||= VMDB::Util.http_proxy_uri

    require 'aws-sdk-v1'
    AWS.const_get(service).new(
      :access_key_id     => access_key_id,
      :secret_access_key => secret_access_key,
      :region            => region,
      :proxy_uri         => proxy_uri,

      :logger            => $aws_log,
      :log_level         => :debug,
      :log_formatter     => AWS::Core::LogFormatter.new(AWS::Core::LogFormatter.default.pattern.chomp)
    )
  end

  def self.raw_connect_v2(access_key_id, secret_access_key, service, region, proxy_uri = nil)
    service ||= "EC2"
    proxy_uri ||= VMDB::Util.http_proxy_uri

    require 'aws-sdk'
    Aws.const_get(service)::Resource.new(
      :access_key_id     => access_key_id,
      :secret_access_key => secret_access_key,
      :region            => region,
      :http_proxy        => proxy_uri,
      :logger            => $aws_log,
      :log_level         => :debug,
      :log_formatter     => Aws::Log::Formatter.new(Aws::Log::Formatter.default.pattern.chomp)
    )
  end

  def browser_url
    "https://console.aws.amazon.com/ec2/v2/home?region=#{provider_region}"
  end

  def connect(options = {})
    raise "no credentials defined" if self.missing_credentials?(options[:auth_type])

    username = options[:user] || authentication_userid(options[:auth_type])
    password = options[:pass] || authentication_password(options[:auth_type])

    if options[:sdk_v2]
      self.class.raw_connect_v2(username, password, options[:service],
                                provider_region, options[:proxy_uri])
    else
      self.class.raw_connect(username, password, options[:service],
                             provider_region, options[:proxy_uri])
    end
  end

  def translate_exception(err)
    case err
    when Aws::EC2::Errors::SignatureDoesNotMatch
      MiqException::MiqHostError.new "SignatureMismatch - check your AWS Secret Access Key and signing method"
    when Aws::EC2::Errors::AuthFailure
      MiqException::MiqHostError.new "Login failed due to a bad username or password."
    when Aws::Errors::MissingCredentialsError
      MiqException::MiqHostError.new "Missing credentials"
    else
      MiqException::MiqHostError.new "Unexpected response returned from system: #{err.message}"
    end
  end

  def verify_credentials(auth_type = nil, options = {})
    raise MiqException::MiqHostError, "No credentials defined" if self.missing_credentials?(auth_type)

    begin
      # EC2 does Lazy Connections, so call a cheap function
      with_provider_connection(options.merge(:auth_type => auth_type, :sdk_v2 => true)) do |ec2|
        ec2.client.describe_regions.regions.map(&:region_name)
      end
    rescue => err
      miq_exception = translate_exception(err)
      raise unless miq_exception

      _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
      raise miq_exception
    end

    true
  end

  def ec2
    @ec2 ||= connect(:service => "EC2", :sdk_v2 => true)
  end

  def s3
    @s3 ||= connect(:service => "S3")
  end

  def sqs
    @sqs ||= connect(:service => "SQS")
  end

  def cloud_formation
    @cloud_formation ||= connect(:service => "CloudFormation", :sdk_v2 => true)
  end

  #
  # Operations
  #

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
    vm.vm_destroy
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_reboot_guest(vm, _options = {})
    vm.reboot_guest
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  # @param [OrchestrationTemplateCfn] template
  # @return [nil] if the template is valid
  # @return [String] if the template is invalid this is the error message
  def orchestration_template_validate(template)
    nil if cloud_formation.client.validate_template(:template_body => template.content)
  rescue Aws::CloudFormation::Errors::ValidationError => validation_error
    validation_error.message
  rescue => err
    _log.error "template=[#{template.name}], error: #{err}"
    raise MiqException::MiqOrchestrationValidationError, err.to_s, err.backtrace
  end

  #
  # Discovery
  #

  # Factory method to create EmsAmazon instances for all regions with instances
  #   or images for the given authentication.  Created EmsAmazon instances
  #   will automatically have EmsRefreshes queued up.  If this is a greenfield
  #   discovery, we will at least add an EmsAmazon for us-east-1
  def self.discover(access_key_id, secret_access_key)
    new_emses = []

    all_emses = includes(:authentications)
    all_ems_names = all_emses.index_by(&:name)

    known_emses = all_emses.select { |e| e.authentication_userid == access_key_id }
    known_ems_regions = known_emses.index_by(&:provider_region)

    ec2 = raw_connect_v2(access_key_id, secret_access_key, "EC2", "us-east-1")
    ec2.client.describe_regions.regions.each do |region|
      next if known_ems_regions.include?(region.region_name)
      resource_for_region = raw_connect_v2(access_key_id, secret_access_key, "EC2", region.region_name)
      next if resource_for_region.instances.count == 0 && # instances
              resource_for_region.images(:owners => %w(self)).count == 0 && # private images
              resource_for_region.images(:executable_users => %w(self)).count == 0 # shared  images
      new_emses << create_discovered_region(region.region_name, access_key_id, secret_access_key, all_ems_names)
    end

    # If greenfield Amazon, at least create the us-east-1 region.
    if new_emses.blank? && known_emses.blank?
      new_emses << create_discovered_region("us-east-1", access_key_id, secret_access_key, all_ems_names)
    end

    EmsRefresh.queue_refresh(new_emses) unless new_emses.blank?

    new_emses
  end

  def self.discover_queue(access_key_id, secret_access_key)
    MiqQueue.put(
      :class_name  => name,
      :method_name => "discover_from_queue",
      :args        => [access_key_id, MiqPassword.encrypt(secret_access_key)]
    )
  end

  private

  def self.discover_from_queue(access_key_id, secret_access_key)
    discover(access_key_id, MiqPassword.decrypt(secret_access_key))
  end

  def self.create_discovered_region(region_name, access_key_id, secret_access_key, all_ems_names)
    name = region_name
    name = "#{region_name} #{access_key_id}" if all_ems_names.key?(name)
    while all_ems_names.key?(name)
      name_counter = name_counter.to_i + 1 if defined?(name_counter)
      name = "#{region_name} #{name_counter}"
    end

    new_ems = self.create!(
      :name            => name,
      :provider_region => region_name,
      :zone            => Zone.default_zone
    )
    new_ems.update_authentication(
      :default => {
        :userid   => access_key_id,
        :password => secret_access_key
      }
    )

    new_ems
  end
end
