class MiqRemoteConsoleWorker < MiqWorker
  self.required_roles = ['remote_console']

  RACK_APPLICATION = RemoteConsole::RackServer
  STARTING_PORT    = 5000

  def friendly_name
    @friendly_name ||= "Remote Console Worker"
  end

  include MiqWebServerWorkerMixin
  include MiqWorker::ServiceWorker

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_REMOTE_CONSOLE_WORKERS
  end

  def container_port
    3001
  end

  def configure_service_worker_deployment(definition)
    super

    definition[:spec][:template][:spec][:containers].first[:volumeMounts] << {:name => "remote-console-httpd-config", :mountPath => "/etc/httpd/conf.d"}
    definition[:spec][:template][:spec][:volumes] << {:name => "remote-console-httpd-config", :configMap => {:name => "remote-console-httpd-configs", :defaultMode => 420}}

    if ENV["REMOTE_CONSOLE_SSL_SECRET_NAME"].present?
      definition[:spec][:template][:spec][:containers].first[:volumeMounts] << {:name => "remote-console-httpd-ssl", :mountPath => "/etc/pki/tls"}
      definition[:spec][:template][:spec][:volumes] << {:name => "remote-console-httpd-ssl", :secret => {:secretName => ENV["REMOTE_CONSOLE_SSL_SECRET_NAME"], :items => [{:key => "remote_console_crt", :path => "certs/server.crt"}, {:key => "remote_console_key", :path => "private/server.key"}], :defaultMode => 400}}
    end
  end
end
