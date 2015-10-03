require 'MiqContainerGroup/MiqContainerGroup'

module ManageIQ::Providers::Kubernetes::ContainerManagerMixin
  extend ActiveSupport::Concern

  module ClassMethods
    def raw_api_endpoint(hostname, port)
      URI::HTTPS.build(:host => hostname, :port => port.presence.try(:to_i))
    end

    def verify_ssl_mode
      # TODO: support real authentication using certificates
      OpenSSL::SSL::VERIFY_NONE
    end

    def kubernetes_connect(hostname, port, options)
      require 'kubeclient'

      Kubeclient::Client.new(
        raw_api_endpoint(hostname, port),
        kubernetes_version,
        :ssl_options  => {:verify_ssl => verify_ssl_mode},
        :auth_options => kubernetes_auth_options(options),
      )
    end

    def kubernetes_auth_options(options)
      auth_options = {}
      if options[:username] && options[:password]
        auth_options[:username] = options[:username]
        auth_options[:password] = options[:password]
      end
      auth_options[:bearer_token] = options[:bearer] if options[:bearer]
      auth_options
    end

    def kubernetes_version
      'v1'
    end
  end

  # UI methods for determining availability of fields
  def supports_port?
    true
  end

  def api_endpoint
    self.class.raw_api_endpoint(hostname, port)
  end

  def verify_ssl_mode
    # TODO: support real authentication using certificates
    self.class.verify_ssl_mode
  end

  def connect(options = {})
    options[:hostname] ||= address
    options[:port] ||= port
    options[:user] ||= authentication_userid(options[:auth_type])
    options[:pass] ||= authentication_password(options[:auth_type])
    options[:bearer] ||= authentication_token(options[:auth_type] || 'bearer')
    self.class.raw_connect(options[:hostname], options[:port], options)
  end

  def verify_credentials(auth_type = nil, options = {})
    options = options.merge(:auth_type => auth_type)

    with_provider_connection(options, &:api_valid?)
  rescue SocketError,
         Errno::ECONNREFUSED,
         RestClient::ResourceNotFound,
         RestClient::InternalServerError => err
    raise MiqException::MiqUnreachableError, err.message, err.backtrace
  rescue RestClient::Unauthorized   => err
    raise MiqException::MiqInvalidCredentialsError, err.message, err.backtrace
  end

  def ensure_authentications_record
    return if authentications.present?
    update_authentication(:default => {:userid => "_", :save => false})
  end

  def supported_auth_types
    %w(default password bearer)
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  def default_authentication_type
    :bearer
  end

  def scan_job_create(entity_class, entity_id)
    Job.create_job(
      "ManageIQ::Providers::Kubernetes::ContainerManager::Scanning::Job",
      :name            => "Container image analysis",
      :target_class    => entity_class,
      :target_id       => entity_id,
      :zone            => my_zone,
      :miq_server_host => MiqServer.my_server.hostname,
      :miq_server_guid => MiqServer.my_server.guid
    )
  end

  SCAN_CONTENT_PATH = '/api/v1/content'

  def scan_entity_create(scan_data)
    client = ext_management_system.connect(:service => 'kubernetes')
    pod_proxy = client.proxy_url(:pod,
                                 scan_data[:pod_name],
                                 scan_data[:pod_port],
                                 scan_data[:pod_namespace])
    MiqContainerGroup.new(pod_proxy + SCAN_CONTENT_PATH,
                          verify_ssl_mode,
                          client.headers.stringify_keys,
                          scan_data[:guest_os])
  end
end
