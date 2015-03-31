class EmsKubernetes < EmsContainer
  has_many :container_nodes,                      :foreign_key => :ems_id, :dependent => :destroy
  has_many :container_groups,                     :foreign_key => :ems_id, :dependent => :destroy
  has_many :container_services,                   :foreign_key => :ems_id, :dependent => :destroy

  def self.ems_type
    @ems_type ||= "kubernetes".freeze
  end

  def self.description
    @description ||= "Kubernetes".freeze
  end

  def self.raw_connect(hostname, port, api_version)
    require 'kubeclient'
    api_endpoint = raw_api_endpoint(hostname, port)
    Kubeclient::Client.new(api_endpoint, api_version)
  end

  def self.raw_api_endpoint(hostname, port)
    URI::HTTP.build(:host => hostname, :port => port.to_i, :path => "/api")
  end

  # UI methods for determining availability of fields
  def supports_port?
    false
  end
  
  def api_endpoint
    self.class.raw_api_endpoint(hostname, port)
  end


  def connect(_options = {})
    self.class.raw_connect(hostname, port, api_version)
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
