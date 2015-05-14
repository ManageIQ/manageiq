module ContainerProviderMixin
  extend ActiveSupport::Concern

  included do
    has_many :container_nodes, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_groups, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_services, :foreign_key => :ems_id, :dependent => :destroy
    has_many :container_replication_controllers, :foreign_key => :ems_id, :dependent => :destroy

    # TODO: support real authentication using certificates
    before_validation :ensure_authentications_record
  end

  module ClassMethods
    def raw_api_endpoint(hostname, port)
      URI::HTTPS.build(:host => hostname, :port => port.presence.try(:to_i))
    end

    def kubernetes_connect(hostname, port)
      require 'kubeclient'
      api_endpoint = raw_api_endpoint(hostname, port)
      kubeclient = Kubeclient::Client.new(api_endpoint, kubernetes_version)
      # TODO: support real authentication using certificates
      kubeclient.ssl_options(:verify_ssl => OpenSSL::SSL::VERIFY_NONE)
      kubeclient
    end

    def kubernetes_version
      'v1beta3'
    end
  end

  # UI methods for determining availability of fields
  def supports_port?
    true
  end

  def api_endpoint
    self.class.raw_api_endpoint(hostname, port)
  end

  def connect(options = {})
    hostname = options[:hostname] || address
    port     = options[:port] || self.port
    self.class.raw_connect(hostname, port, options[:service])
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
    # TODO: support real authentication using certificates
    return if authentications.present?
    update_authentication(:default => {:userid => "_", :save => false})
  end

  # required by aggregate_hardware
  def all_computer_system_ids
    MiqPreloader.preload(container_nodes, :computer_system)
    container_nodes.collect { |n| n.computer_system.id }
  end

  def aggregate_logical_cpus(targets = nil)
    aggregate_hardware(:computer_systems, :logical_cpus, targets)
  end

  def aggregate_memory(targets = nil)
    aggregate_hardware(:computer_systems, :memory_cpu, targets)
  end
end
