autoload(:Kubeclient, 'kubeclient')
autoload(:KubeException, 'kubeclient')

class ContainerOrchestrator
  include Vmdb::Logging
  include ObjectDefinition

  TOKEN_FILE   = "/run/secrets/kubernetes.io/serviceaccount/token".freeze
  CA_CERT_FILE = "/run/secrets/kubernetes.io/serviceaccount/ca.crt".freeze

  def self.available?
    File.exist?(TOKEN_FILE) && File.exist?(CA_CERT_FILE)
  end

  def scale(deployment_name, replicas)
    patch_deployment(deployment_name, {:spec => {:replicas => replicas}})
  end

  def patch_deployment(deployment_name, data)
    _log.info("deployment_name: #{deployment_name}, data: #{data.inspect}")
    kube_apps_connection.patch_deployment(deployment_name, data, my_namespace)
  end

  def create_deployment(name)
    definition = deployment_definition(name)
    yield(definition) if block_given?
    kube_apps_connection.create_deployment(definition)
  rescue KubeException => e
    raise unless /already exists/.match?(e.message)
  end

  def create_service(name, selector, port)
    definition = service_definition(name, selector, port)
    yield(definition) if block_given?
    kube_connection.create_service(definition)
  rescue KubeException => e
    raise unless /already exists/.match?(e.message)
  end

  def create_secret(name, data)
    definition = secret_definition(name, data)
    yield(definition) if block_given?
    kube_connection.create_secret(definition)
  rescue KubeException => e
    raise unless /already exists/.match?(e.message)
  end

  def delete_deployment(name)
    _log.info("Deleting [#{name}] in namespace: #{my_namespace}")
    scale(name, 0)
    kube_apps_connection.delete_deployment(name, my_namespace)
  rescue KubeException => e
    raise unless /not found/.match?(e.message)
  end

  def delete_service(name)
    kube_connection.delete_service(name, my_namespace)
  rescue KubeException => e
    raise unless /not found/.match?(e.message)
  end

  def delete_secret(name)
    kube_connection.delete_secret(name, my_namespace)
  rescue KubeException => e
    raise unless /not found/.match?(e.message)
  end

  def get_deployments
    kube_apps_connection.get_deployments(default_get_options)
  end

  def watch_deployments(resource_version = nil)
    kube_apps_connection.watch_deployments(default_get_options.merge(:resource_version => resource_version))
  end

  def get_pods
    kube_connection.get_pods(default_get_options)
  end

  def watch_pods(resource_version = nil)
    kube_connection.watch_pods(default_get_options.merge(:resource_version => resource_version))
  end

  # Returns the pod with the given hostname in the given namespace.
  def get_pod_by_namespace_and_hostname(namespace, hostname)
    kube_connection.get_pods(:namespace => namespace).detect { |i| i.metadata.name == hostname }
  end

  # Returns the pod for this container orchestrator.
  #
  # NOTE: It is presumed that this method is only called from within the
  #       container orchestrator process itself, as it uses environment info
  #       that only the running orchestrator pod will have.
  def my_pod
    get_pod_by_namespace_and_hostname(my_namespace, ENV["HOSTNAME"])
  end

  def my_node_affinity_arch_values
    ContainerOrchestrator.new.my_pod.spec.affinity&.nodeAffinity&.requiredDuringSchedulingIgnoredDuringExecution&.nodeSelectorTerms&.each do |i|
      i.matchExpressions&.each { |a| return(a.values) if a.key == "kubernetes.io/arch" }
    end

    ["amd64"]
  end

  private

  def default_get_options
    {:namespace => my_namespace, :label_selector => [app_name_selector, orchestrated_by_selector].join(",")}
  end

  def kube_connection
    @kube_connection ||= raw_connect(manager_uri("/api"))
  end

  def kube_apps_connection
    @kube_apps_connection ||= raw_connect(manager_uri("/apis/apps"))
  end

  def raw_connect(uri)
    ssl_options = {
      :verify_ssl => OpenSSL::SSL::VERIFY_PEER,
      :ca_file    => CA_CERT_FILE
    }

    Kubeclient::Client.new(
      uri,
      :auth_options => {:bearer_token_file => TOKEN_FILE},
      :ssl_options  => ssl_options
    )
  end

  def manager_uri(path)
    URI::HTTPS.build(
      :host => ENV["KUBERNETES_SERVICE_HOST"],
      :port => ENV["KUBERNETES_SERVICE_PORT"],
      :path => path
    )
  end
end
