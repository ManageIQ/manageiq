class ManageIQ::Providers::Kubernetes::ContainerManager < ManageIQ::Providers::ContainerManager
  require_dependency 'manageiq/providers/kubernetes/container_manager/container'
  require_dependency 'manageiq/providers/kubernetes/container_manager/container_group'
  require_dependency 'manageiq/providers/kubernetes/container_manager/container_node'
  require_dependency 'manageiq/providers/kubernetes/container_manager/event_catcher'
  require_dependency 'manageiq/providers/kubernetes/container_manager/event_catcher_mixin'
  require_dependency 'manageiq/providers/kubernetes/container_manager/event_parser'
  require_dependency 'manageiq/providers/kubernetes/container_manager/event_parser_mixin'
  require_dependency 'manageiq/providers/kubernetes/container_manager/metrics_capture'
  require_dependency 'manageiq/providers/kubernetes/container_manager/metrics_collector_worker'
  require_dependency 'manageiq/providers/kubernetes/container_manager/refresh_parser'
  require_dependency 'manageiq/providers/kubernetes/container_manager/refresh_worker'
  require_dependency 'manageiq/providers/kubernetes/container_manager/refresher'

  include ManageIQ::Providers::Kubernetes::ContainerManagerMixin

  DEFAULT_PORT = 6443
  default_value_for :port, DEFAULT_PORT

  # This is the API version that we use and support throughout the entire code
  # (parsers, events, etc.). It should be explicitly selected here and not
  # decided by the user nor out of control in the defaults of kubeclient gem
  # because it's not guaranteed that the next default version will work with
  # our specific code in ManageIQ.
  def api_version
    self.class.api_version
  end

  def api_version=(_value)
    raise 'Kubernetes api_version cannot be modified'
  end

  def self.api_version
    kubernetes_version
  end

  def self.ems_type
    @ems_type ||= "kubernetes".freeze
  end

  def self.description
    @description ||= "Kubernetes".freeze
  end

  def self.raw_connect(hostname, port, options)
    kubernetes_connect(hostname, port, options)
  end

  def self.event_monitor_class
    ManageIQ::Providers::Kubernetes::ContainerManager::EventCatcher
  end
end
