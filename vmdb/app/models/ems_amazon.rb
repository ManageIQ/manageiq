require 'Amazon/ec2/regions'
require 'Amazon/amazon_connection'

class EmsAmazon < EmsCloud
  def self.ems_type
    @ems_type ||= "ec2".freeze
  end

  def self.description
    @description ||= "Amazon EC2".freeze
  end

  def hostname_ipaddress_required?
    false
  end

  validates :hostname, :inclusion => { :in => ::Amazon::EC2::Regions.names }

  def description
    ::Amazon::EC2::Regions.find_by_name(self.hostname)[:description]
  end

  #
  # Connections
  #

  def self.raw_connect(access_key_id, secret_access_key, service = nil, region = nil, proxy_uri = nil)
    service   ||= "EC2"
    proxy_uri ||= VMDB::Util.http_proxy_uri
    AmazonConnection.raw_connect(access_key_id, secret_access_key, service, region, proxy_uri)
  end

  def browser_url
    "https://console.aws.amazon.com/ec2/v2/home?region=#{hostname}"
  end

  def connect(options = {})
    raise "no credentials defined" if self.authentication_invalid?(options[:auth_type])

    username = options[:user] || self.authentication_userid(options[:auth_type])
    password = options[:pass] || self.authentication_password(options[:auth_type])

    self.class.raw_connect(username, password, options[:service], self.hostname, options[:proxy_uri])
  end

  def verify_credentials(auth_type=nil, options={})
    raise MiqException::MiqHostError, "No credentials defined" if self.authentication_invalid?(auth_type)

    begin
      # EC2 does Lazy Connections, so call a cheap function
      with_provider_connection(options.merge(:auth_type => auth_type)) { |ec2| ec2.regions.map(&:name) }
    rescue AWS::EC2::Errors::SignatureDoesNotMatch => err
      raise MiqException::MiqHostError, "SignatureMismatch - check your AWS Secret Access Key and signing method"
    rescue AWS::EC2::Errors::AuthFailure => err
      raise MiqException::MiqHostError, "Login failed due to a bad username or password."
    rescue Exception => err
      $log.error("MIQ(#{self.class.name}.verify_credentials) Error Class=#{err.class.name}, Message=#{err.message}")
      raise MiqException::MiqHostError, "Unexpected response returned from system, see log for details"
    end

    return true
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
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  def vm_stop(vm, options = {})
    vm.stop
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  def vm_destroy(vm, options = {})
    vm.vm_destroy
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
  end

  def vm_reboot_guest(vm, options = {})
    vm.reboot_guest
  rescue => err
    $log.error "MIQ(#{self.class.name}##{__method__}) vm=[#{vm.name}], error: #{err}"
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

    all_emses = self.includes(:authentications).all
    all_ems_names = all_emses.index_by(&:name)

    known_emses = all_emses.select { |e| e.authentication_userid == access_key_id }
    known_ems_hostnames = known_emses.index_by(&:hostname)

    ec2 = raw_connect(access_key_id, secret_access_key)
    ec2.regions.each do |region|
      next if known_ems_hostnames.include?(region.name)
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
      :name     => name,
      :hostname => region_name,
      :zone     => Zone.default_zone
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
