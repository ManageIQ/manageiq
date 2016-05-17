module ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::HawkularClientMixin
  def hawkular_client
    require 'hawkular_all'
    @client ||= Hawkular::Metrics::Client.new(
      hawkular_entrypoint, hawkular_credentials, hawkular_options)
  end

  def hawkular_entrypoint
    hawkular_endpoint = @ext_management_system.connection_configurations.hawkular.try(:endpoint)
    worker_class = ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCollectorWorker

    URI::HTTPS.build(
      :host => hawkular_endpoint ? hawkular_endpoint.hostname : @ext_management_system.hostname,
      :port => hawkular_endpoint ? hawkular_endpoint.port : worker_class.worker_settings[:metrics_port],
      :path => worker_class.worker_settings[:metrics_path])
  end

  def hawkular_credentials
    {:token => @ext_management_system.try(:authentication_token)}
  end

  def hawkular_options
    {:tenant     => @tenant,
     :verify_ssl => @ext_management_system.verify_ssl_mode}
  end

  def status
    @client.http_get('/status')
  end
end
