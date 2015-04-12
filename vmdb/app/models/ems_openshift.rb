class EmsOpenshift < EmsContainer
  include ContainerProviderMixin

  has_many :container_routes,                      :foreign_key => :ems_id, :dependent => :destroy
  has_many :container_projects,                    :foreign_key => :ems_id, :dependent => :destroy

  default_value_for :port, 8443

  def self.api_version
    'v1beta1'
  end

  def self.ems_type
    @ems_type ||= "openshift".freeze
  end

  def self.description
    @description ||= "OpenShift".freeze
  end

  def self.raw_connect(hostname, port, service = nil)
    service   ||= "openshift"
    send("#{service}_connect", hostname, port)
  end

  def self.openshift_connect(hostname, port)
    require 'openshift_client'
    api_endpoint = raw_api_endpoint(hostname, port)
    osclient = OpenshiftClient::Client.new(api_endpoint, api_version)
    # TODO: support real authentication using certificates
    osclient.ssl_options(:verify_ssl => OpenSSL::SSL::VERIFY_NONE)
    osclient
  end
end
