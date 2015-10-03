class ManageIQ::Providers::Openshift::ContainerManager < ManageIQ::Providers::ContainerManager
  require_dependency 'manageiq/providers/openshift/container_manager/event_catcher'
  require_dependency 'manageiq/providers/openshift/container_manager/event_parser'
  require_dependency 'manageiq/providers/openshift/container_manager/metrics_collector_worker'
  require_dependency 'manageiq/providers/openshift/container_manager/refresh_parser'
  require_dependency 'manageiq/providers/openshift/container_manager/refresh_worker'
  require_dependency 'manageiq/providers/openshift/container_manager/refresher'

  include ManageIQ::Providers::Kubernetes::ContainerManagerMixin

  has_many :container_routes, :foreign_key => :ems_id, :dependent => :destroy

  DEFAULT_PORT = 8443
  default_value_for :port, DEFAULT_PORT

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
    'v1'
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

    OpenshiftClient::Client.new(
      raw_api_endpoint(hostname, port),
      api_version,
      :ssl_options  => {:verify_ssl => verify_ssl_mode},
      :auth_options => kubernetes_auth_options(options),
    )
  end

  def self.event_monitor_class
    ManageIQ::Providers::Openshift::ContainerManager::EventCatcher
  end
end
