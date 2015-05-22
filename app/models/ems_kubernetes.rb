class EmsKubernetes < EmsContainer
  include KubernetesProviderMixin

  default_value_for :port, 6443

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

  def supported_auth_types
    %w(default password bearer)
  end

  def supports_authentication?(authtype)
    supported_auth_types.include?(authtype.to_s)
  end

  def self.raw_connect(hostname, port, options)
    kubernetes_connect(hostname, port, options)
  end

  def self.event_monitor_class
    MiqEventCatcherKubernetes
  end
end
