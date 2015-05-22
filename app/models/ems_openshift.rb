class EmsOpenshift < EmsContainer
  include KubernetesProviderMixin

  has_many :container_routes,                      :foreign_key => :ems_id, :dependent => :destroy
  has_many :container_projects,                    :foreign_key => :ems_id, :dependent => :destroy

  default_value_for :port, 8443

  # This is the API version that we use and support throughout the entire code
  # (parsers, events, etc.). It should be explicitly selected here and not
  # decided by the user nor out of control in the defaults of openshift gem
  # because it's not guaranteed that the next default version will work with
  # our specific code in ManageIQ.
  def api_version
    self.class.api_version
  end

  def api_version=(_value)
    raise 'OpenShift api_version cannot be modified'
  end

  def self.api_version
    'v1beta1'
  end

  def self.ems_type
    @ems_type ||= "openshift".freeze
  end

  def self.description
    @description ||= "OpenShift".freeze
  end

  def self.raw_connect(hostname, port, options)
    options[:service] ||= "openshift"
    send("#{options[:service]}_connect", hostname, port, options)
  end

  def self.openshift_connect(hostname, port, options)
    require 'openshift_client'
    api_endpoint = raw_api_endpoint(hostname, port)
    osclient = OpenshiftClient::Client.new(api_endpoint, api_version)
    # TODO: support real authentication using certificates
    osclient.ssl_options(:verify_ssl => OpenSSL::SSL::VERIFY_NONE)
    osclient.bearer_token(options[:bearer]) if options[:bearer]
    osclient
  end

  def self.event_monitor_class
    MiqEventCatcherOpenshift
  end
end
