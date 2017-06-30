class ContainerOrchestrator
  TOKEN_FILE = "/run/secrets/kubernetes.io/serviceaccount/token".freeze

  def scale(deployment_config_name, replicas)
    connection.patch_deployment_config(deployment_config_name, { :spec => { :replicas => replicas } }, ENV["MY_POD_NAMESPACE"])
  end

  private

  def connection
    require 'kubeclient'

    @connection ||=
      Kubeclient::Client.new(
        manager_uri,
        :auth_options => { :bearer_token_file => TOKEN_FILE },
        :ssl_options  => { :verify_ssl => OpenSSL::SSL::VERIFY_NONE }
      )
  end

  def manager_uri
    URI::HTTPS.build(
      :host => ENV["KUBERNETES_SERVICE_HOST"],
      :port => ENV["KUBERNETES_SERVICE_PORT"],
      :path => "/oapi"
    )
  end
end
