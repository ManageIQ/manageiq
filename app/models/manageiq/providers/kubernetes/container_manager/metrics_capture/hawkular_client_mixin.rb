module ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::HawkularClientMixin
  def hawkular_client
    require 'hawkular/hawkular_client'

    @hawkular_entrypoint ||= hawkular_entrypoint
    @hawkular_credentials ||= hawkular_credentials
    @hawkular_options ||= hawkular_options

    Hawkular::Metrics::Client.new(
      @hawkular_entrypoint, @hawkular_credentials, @hawkular_options)
  end

  def hawkular_entrypoint
    hawkular_endpoint = @ext_management_system.connection_configurations.hawkular.try(:endpoint)
    hawkular_endpoint_empty = hawkular_endpoint.try(:hostname).blank?
    worker_class = ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCollectorWorker

    URI::HTTPS.build(
      :host => hawkular_endpoint_empty ? @ext_management_system.hostname : hawkular_endpoint.hostname,
      :port => hawkular_endpoint_empty ? worker_class.worker_settings[:metrics_port] : hawkular_endpoint.port,
      :path => worker_class.worker_settings[:metrics_path] || '/hawkular/metrics')
  end

  def hawkular_credentials
    {:token => @ext_management_system.try(:authentication_token)}
  end

  def hawkular_options
    { :tenant         => @tenant,
      :verify_ssl     => @ext_management_system.verify_ssl_mode,
      :http_proxy_uri => VMDB::Util.http_proxy_uri.to_s,
      :timeout        => 100
    }
  end

  def hawkular_try_connect
    # check the connection and the credentials by trying
    # to access hawkular's availability private data, and fetch one line of data.
    # this will check the connection and the credentials
    # because only if the connection is ok, and the token is valid,
    # we will get an OK response, with an array of data, or an empty array
    # if no data availabel.
    hawkular_client.avail.get_data('all', :limit => 1).kind_of?(Array)
  end
end
