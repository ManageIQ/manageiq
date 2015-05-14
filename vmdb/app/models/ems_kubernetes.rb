class EmsKubernetes < EmsContainer
  include ContainerProviderMixin

  default_value_for :port, 6443

  # This is the API version that we use and support throughout the entire code
  # (parsers, events, etc.). It should be explicitly selected here and not
  # decided by the user nor out of control in the defaults of kubeclient gem
  # because it's not guaranteed that the next default version will work with
  # our specific code in ManageIQ.
  def self.api_version
    kubernetes_version
  end

  def self.ems_type
    @ems_type ||= "kubernetes".freeze
  end

  def self.description
    @description ||= "Kubernetes".freeze
  end

  def self.raw_connect(hostname, port, _service = nil)
    kubernetes_connect(hostname, port)
  end

  def self.event_monitor_class
    MiqEventCatcherKubernetes
  end
end
