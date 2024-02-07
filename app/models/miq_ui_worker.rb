class MiqUiWorker < MiqWorker
  self.required_roles = ['user_interface']

  STARTING_PORT = 3000

  def friendly_name
    @friendly_name ||= "User Interface Worker"
  end

  include MiqWebServerWorkerMixin
  include MiqWorker::ServiceWorker

  def self.bundler_groups
    %w[manageiq_default ui_dependencies]
  end

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_UI_WORKERS
  end

  def self.preload_for_worker_role
    super
    Api::ApiConfig.collections.each { |_k, v| v.klass.try(:constantize).try(:descendants) }

    # There is a race condition between const_missing and singleton which can occur
    # when one thread is holding the singleton lock and loading a constant while
    # another thread is holding the signleton lock and waiting to load a different
    # constant.
    #
    # As a workaround preload all classes which are Singletons from a single thread
    # prior to booting the puma workers.
    ApplicationHelper::Toolbar::Base.instance
    Menu::Manager.instance
  end

  def container_port
    3001
  end

  def container_image_name
    "manageiq-ui-worker"
  end

  def container_image
    ENV["UI_WORKER_IMAGE"] || default_image
  end

  def configure_service_worker_deployment(definition)
    super

    definition[:spec][:template][:spec][:containers].first[:volumeMounts] << {:name => "ui-httpd-configs", :mountPath => "/etc/httpd/conf.d"}
    definition[:spec][:template][:spec][:volumes] << {:name => "ui-httpd-configs", :configMap => {:name => "ui-httpd-configs", :defaultMode => 420}}

    if ENV["UI_SSL_SECRET_NAME"].present?
      definition[:spec][:template][:spec][:containers].first[:volumeMounts] << {:name => "ui-httpd-ssl", :mountPath => "/etc/pki/tls"}
      definition[:spec][:template][:spec][:volumes] << {:name => "ui-httpd-ssl", :secret => {:secretName => ENV["UI_SSL_SECRET_NAME"], :items => [{:key => "ui_crt", :path => "certs/server.crt"}, {:key => "ui_key", :path => "private/server.key"}], :defaultMode => 400}}
    end
  end
end
