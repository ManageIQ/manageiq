require 'Amazon/ec2/regions'
require 'Amazon/amazon_connection'

class EmsAmazon < EmsCloud
  def self.ems_type
    @ems_type ||= "ec2".freeze
  end

  def self.description
    @description ||= "Amazon EC2".freeze
  end

  def self.hostname_required?
    false
  end

  validates :provider_region, :inclusion => { :in => ::Amazon::EC2::Regions.names }

  def description
    ::Amazon::EC2::Regions.find_by_name(provider_region)[:description]
  end

  #
  # Connections
  #

  def self.raw_connect(access_key_id, secret_access_key, service, region = nil, proxy_uri = nil)
    service   ||= "EC2"
    proxy_uri ||= VMDB::Util.http_proxy_uri

    require 'aws-sdk'
    AWS.const_get(service).new(
      :access_key_id => access_key_id,
      :secret_access_key => secret_access_key,
      :region => region,
      :proxy_uri => proxy_uri,

      :logger        => $aws_log,
      :log_level     => :debug,
      :log_formatter => AWS::Core::LogFormatter.new(AWS::Core::LogFormatter.default.pattern.chomp)
    )
  end

  def browser_url
    "https://console.aws.amazon.com/ec2/v2/home?region=#{provider_region}"
  end

  def connect(options = {})
    raise "no credentials defined" if self.missing_credentials?(options[:auth_type])

    username = options[:user] || self.authentication_userid(options[:auth_type])
    password = options[:pass] || self.authentication_password(options[:auth_type])

    self.class.raw_connect(username, password, options[:service], provider_region, options[:proxy_uri])
  end

  def translate_exception(err)
    case err
    when AWS::EC2::Errors::SignatureDoesNotMatch
      MiqException::MiqHostError.new "SignatureMismatch - check your AWS Secret Access Key and signing method"
    when AWS::EC2::Errors::AuthFailure
      MiqException::MiqHostError.new "Login failed due to a bad username or password."
    when AWS::Errors::MissingCredentialsError
      MiqException::MiqHostError.new "Missing credentials"
    else
      MiqException::MiqHostError.new "Unexpected response returned from system: #{err.message}"
    end
  end

  def verify_credentials(auth_type=nil, options={})
    raise MiqException::MiqHostError, "No credentials defined" if self.missing_credentials?(auth_type)

    begin
      # EC2 does Lazy Connections, so call a cheap function
      with_provider_connection(options.merge(:auth_type => auth_type)) { |ec2| ec2.regions.map(&:name) }
    rescue => err
      miq_exception = translate_exception(err)
      raise unless miq_exception

      _log.error("Error Class=#{err.class.name}, Message=#{err.message}")
      raise miq_exception
    end

    true
  end

  def ec2
    @ec2 ||= connect(:service => "EC2")
  end

  def s3
    @s3 ||= connect(:service => "S3")
  end

  def sqs
    @sqs ||= connect(:service => "SQS")
  end

  def cloud_formation
    @cloud_formation ||= connect(:service => "CloudFormation")
  end

  #
  # Operations
  #

  def extract_queue
    @extract_queue ||= begin
      require 'ec2Extract/Ec2ExtractQueue'
      Ec2ExtractQueue.new(
        :sqs            => sqs,
        :s3             => s3,
        :request_queue  => 'evm_extract_request',
        :reply_queue    => 'evm_extract_reply',
        :reply_prefix   => 'extract/queue-reply/',
        :account_info   => {
          :account_id   => self.authentication_userid(:default)
        }
      )
    end
  end

  def request_metadata_scan(ec2_id, ost)
    extract_queue.send_extract_request(ec2_id, ost.taskid, ost.category.split(','))
  end

  def vm_start(vm, options = {})
    vm.start
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_stop(vm, options = {})
    vm.stop
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_destroy(vm, options = {})
    vm.vm_destroy
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def vm_reboot_guest(vm, options = {})
    vm.reboot_guest
  rescue => err
    _log.error "vm=[#{vm.name}], error: #{err}"
  end

  def stack_create(stack_name, template, options = {})
    cloud_formation.stacks.create(stack_name, template.content, options).stack_id
  rescue => err
    _log.error "stack=[#{stack_name}], error: #{err}"
    raise MiqException::MiqOrchestrationProvisionError, err.to_s, err.backtrace
  end

  def stack_status(stack_name, _stack_id)
    stack = cloud_formation.stacks[stack_name]
    return stack.status, stack.status_reason if stack
  rescue => err
    _log.error "stack=[#{stack_name}], error: #{err}"
    raise MiqException::MiqOrchestrationStatusError, err.to_s, err.backtrace
  end

  def orchestration_template_validate(template)
    cloud_formation.validate_template(template.content)[:message]
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

    ec2 = raw_connect(access_key_id, secret_access_key, "EC2")
    ec2.regions.each do |region|
      next if known_ems_regions.include?(region.name)
      next if region.instances.count == 0 &&                 # instances
              region.images.with_owner(:self).count == 0 &&  # private images
              region.images.executable_by(:self).count == 0  # shared  images
      new_emses << create_discovered_region(region.name, access_key_id, secret_access_key, all_ems_names)
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
      :class_name  => self.name,
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
    name = "#{region_name} #{access_key_id}" if all_ems_names.has_key?(name)
    while all_ems_names.has_key?(name)
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
