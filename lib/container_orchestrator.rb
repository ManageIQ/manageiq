require 'kubeclient'

class ContainerOrchestrator
  include_concern 'ObjectDefinition'

  TOKEN_FILE = "/run/secrets/kubernetes.io/serviceaccount/token".freeze

  def scale(deployment_config_name, replicas)
    connection.patch_deployment_config(deployment_config_name, { :spec => { :replicas => replicas } }, my_namespace)
  end

  def create_deployment_config(name)
    definition = deployment_config_definition(name)
    yield(definition) if block_given?
    connection.create_deployment_config(definition)
  rescue KubeException => e
    raise unless e.message =~ /already exists/
  end

  def create_service(name, port)
    definition = service_definition(name, port)
    yield(definition) if block_given?
    kube_connection.create_service(definition)
  rescue KubeException => e
    raise unless e.message =~ /already exists/
  end

  def create_secret(name, data)
    definition = secret_definition(name, data)
    yield(definition) if block_given?
    kube_connection.create_secret(definition)
  rescue KubeException => e
    raise unless e.message =~ /already exists/
  end

  def delete_deployment_config(name)
    rc = kube_connection.get_replication_controllers(
      :label_selector => "openshift.io/deployment-config.name=#{name}",
      :namespace      => my_namespace
    ).first

    connection.delete_deployment_config(name, my_namespace)
    delete_replication_controller(rc.metadata.name) if rc
  end

  def delete_replication_controller(name)
    kube_connection.delete_replication_controller(name, my_namespace)
  end

  def delete_service(name)
    kube_connection.delete_service(name, my_namespace)
  end

  def delete_secret(name)
    kube_connection.delete_secret(name, my_namespace)
  end

  private

  def connection
    @connection ||= raw_connect(manager_uri("/oapi"))
  end

  def kube_connection
    @kube_connection ||= raw_connect(manager_uri("/api"))
  end

  def raw_connect(uri)
    Kubeclient::Client.new(
      uri,
      :auth_options => { :bearer_token_file => TOKEN_FILE },
      :ssl_options  => { :verify_ssl => OpenSSL::SSL::VERIFY_NONE }
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
