class EmsKubernetes < EmsContainer
  has_many :container_nodes,                      :foreign_key => :ems_id, :dependent => :destroy
  has_many :container_groups,                     :foreign_key => :ems_id, :dependent => :destroy
  has_many :container_services,                   :foreign_key => :ems_id, :dependent => :destroy

  default_value_for :port, 6443

  def self.ems_type
    @ems_type ||= "kubernetes".freeze
  end

  def self.description
    @description ||= "Kubernetes".freeze
  end

  def self.raw_connect(hostname, port)
    require 'kubeclient'
    api_endpoint = raw_api_endpoint(hostname, port)
    kube = Kubeclient::Client.new(api_endpoint)
    # TODO: support real authentication using certificates
    kube.ssl_options(:verify_ssl => OpenSSL::SSL::VERIFY_NONE)
    kube
  end

  def self.raw_api_endpoint(hostname, port)
    URI::HTTPS.build(:host => hostname, :port => port.to_i)
  end

  def api_endpoint
    self.class.raw_api_endpoint(hostname, port)
  end

  def connect(_options = {})
    self.class.raw_connect(hostname, port)
  end

  def self.event_monitor_class
    MiqEventCatcherKubernetes
  end

  def authentication_check
    # TODO: support real authentication using certificates
    true
  end

  def verify_credentials(_auth_type = nil, _options = {})
    # TODO: support real authentication using certificates
    true
  end

  def authentication_status_ok?(_type = nil)
    # TODO: support real authentication using certificates
    true
  end
end
