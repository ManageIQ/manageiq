module ManageIQ::Providers::Amazon::ManagerMixin
  extend ActiveSupport::Concern

  included do
    validates :provider_region, :inclusion => {:in => ManageIQ::Providers::Amazon::Regions.names}
  end

  def description
    ManageIQ::Providers::Amazon::Regions.find_by_name(provider_region)[:description]
  end

  #
  # Connections
  #

  def browser_url
    "https://console.aws.amazon.com/ec2/v2/home?region=#{provider_region}"
  end

  def connect(options = {})
    raise "no credentials defined" if missing_credentials?(options[:auth_type])

    username = options[:user] || authentication_userid(options[:auth_type])
    password = options[:pass] || authentication_password(options[:auth_type])
    service  = options[:service] || :EC2

    self.class.raw_connect(username, password, service, provider_region, options[:proxy_uri])
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
    raise MiqException::MiqHostError, "No credentials defined" if missing_credentials?(auth_type)

    begin
      # EC2 does Lazy Connections, so call a cheap function
      with_provider_connection(options.merge(:auth_type => auth_type)) do |ec2|
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

  def validate_timeline
    {:available => false,
     :message   => _("Timeline is not available for %{model}") % {:model => ui_lookup(:model => self.class.to_s)}}
  end

  module ClassMethods
    #
    # Connections
    #

    def raw_connect(access_key_id, secret_access_key, service, region, proxy_uri = nil)
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

    #
    # Discovery
    #

    # Factory method to create EmsAmazon instances for all regions with instances
    #   or images for the given authentication.  Created EmsAmazon instances
    #   will automatically have EmsRefreshes queued up.  If this is a greenfield
    #   discovery, we will at least add an EmsAmazon for us-east-1
    def discover(access_key_id, secret_access_key)
      new_emses         = []
      all_emses         = includes(:authentications)
      all_ems_names     = all_emses.map(&:name).to_set
      known_ems_regions = all_emses.select { |e| e.authentication_userid == access_key_id }.map(&:provider_region)

      ec2 = raw_connect(access_key_id, secret_access_key, :EC2, "us-east-1")
      region_names_to_discover = ec2.client.describe_regions.regions.map(&:region_name)

      (region_names_to_discover - known_ems_regions).each do |region_name|
        ec2_region = raw_connect(access_key_id, secret_access_key, :EC2, region_name)
        next if ec2_region.instances.count == 0 && # instances
                ec2_region.images(:owners => %w(self)).count == 0 && # private images
                ec2_region.images(:executable_users => %w(self)).count == 0 # shared  images
        new_emses << create_discovered_region(region_name, access_key_id, secret_access_key, all_ems_names)
      end

      # If greenfield Amazon, at least create the us-east-1 region.
      if new_emses.blank? && known_ems_regions.blank?
        new_emses << create_discovered_region("us-east-1", access_key_id, secret_access_key, all_ems_names)
      end

      EmsRefresh.queue_refresh(new_emses) unless new_emses.blank?

      new_emses
    end

    def discover_queue(access_key_id, secret_access_key)
      MiqQueue.put(
        :class_name  => name,
        :method_name => "discover_from_queue",
        :args        => [access_key_id, MiqPassword.encrypt(secret_access_key)]
      )
    end

    private

    def discover_from_queue(access_key_id, secret_access_key)
      discover(access_key_id, MiqPassword.decrypt(secret_access_key))
    end

    def create_discovered_region(region_name, access_key_id, secret_access_key, all_ems_names)
      name = region_name
      name = "#{region_name} #{access_key_id}" if all_ems_names.include?(name)
      while all_ems_names.include?(name)
        name_counter = name_counter.to_i + 1 if defined?(name_counter)
        name = "#{region_name} #{name_counter}"
      end

      new_ems = create!(
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
end
