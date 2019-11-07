require 'kubeclient'

class ContainerOrchestrator
  include_concern 'ObjectDefinition'

  TOKEN_FILE   = "/run/secrets/kubernetes.io/serviceaccount/token".freeze
  CA_CERT_FILE = "/run/secrets/kubernetes.io/serviceaccount/ca.crt".freeze

  def self.available?
    File.exist?(TOKEN_FILE) && File.exist?(CA_CERT_FILE)
  end

  def scale(deployment_name, replicas)
    kube_apps_connection.patch_deployment(deployment_name, { :spec => { :replicas => replicas } }, my_namespace)
  end

  def create_deployment(name)
    definition = deployment_definition(name)
    yield(definition) if block_given?
    kube_apps_connection.create_deployment(definition)
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

  def delete_deployment(name)
    scale(name, 0)
    kube_apps_connection.delete_deployment(name, my_namespace)
  rescue KubeException => e
    raise unless e.message =~ /not found/
  end

  def delete_service(name)
    kube_connection.delete_service(name, my_namespace)
  rescue KubeException => e
    raise unless e.message =~ /not found/
  end

  def delete_secret(name)
    kube_connection.delete_secret(name, my_namespace)
  rescue KubeException => e
    raise unless e.message =~ /not found/
  end

  private

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
      :auth_options => { :bearer_token_file => TOKEN_FILE },
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
