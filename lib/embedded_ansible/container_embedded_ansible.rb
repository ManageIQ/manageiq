class ContainerEmbeddedAnsible < EmbeddedAnsible
  ANSIBLE_SERVICE_NAME = "ansible".freeze
  ANSIBLE_SECRETS_NAME = "ansible-secrets".freeze

  def self.available?
    ContainerOrchestrator.available?
  end

  def self.priority
    20
  end

  def start
    create_ansible_secret
    create_ansible_service
    create_ansible_deployment_config

    settings.setup_wait_seconds.times do
      break if alive?

      _log.info("Waiting for Ansible container to respond")
      sleep WAIT_FOR_ANSIBLE_SLEEP
    end
  end

  def stop
    orchestrator.delete_deployment_config(ANSIBLE_SERVICE_NAME)
    orchestrator.delete_service(ANSIBLE_SERVICE_NAME)
    orchestrator.delete_secret(ANSIBLE_SECRETS_NAME)
  end

  alias disable stop

  def running?
    true
  end

  def configured?
    true
  end

  def api_connection
    api_connection_raw(ANSIBLE_SERVICE_NAME, 80)
  end

  private

  def create_ansible_secret
    # NOTE: These keys have to match the ones in #container_environment
    secret_data = {
      "secret-key"        => find_or_create_secret_key,
      "admin-password"    => find_or_create_admin_authentication.password,
      "database-password" => find_or_create_database_authentication.password,
      "rabbit-password"   => find_or_create_rabbitmq_authentication.password
    }

    orchestrator.create_secret(ANSIBLE_SECRETS_NAME, secret_data)
  end

  def create_ansible_service
    orchestrator.create_service(ANSIBLE_SERVICE_NAME, 443) do |service|
      http_port = {
        :name       => "#{ANSIBLE_SERVICE_NAME}-80",
        :port       => 80,
        :targetPort => 80
      }
      service[:spec][:ports] << http_port
    end
  end

  def create_ansible_deployment_config
    orchestrator.create_deployment_config(ANSIBLE_SERVICE_NAME) do |dc|
      dc[:spec][:serviceName] = ANSIBLE_SERVICE_NAME
      dc[:spec][:replicas] = 1

      dc[:spec][:template][:spec][:serviceAccount]     = settings.service_account
      dc[:spec][:template][:spec][:serviceAccountName] = settings.service_account

      container = dc[:spec][:template][:spec][:containers].first
      container[:ports]           = [{:containerPort => 443}, {:containerPort => 80}]
      container[:env]             = container_environment
      container[:image]           = image
      container[:securityContext] = {:privileged => true}

      container.delete(:livenessProbe)
    end
  end

  def container_environment
    rabbit_auth    = find_or_create_rabbitmq_authentication
    database_auth  = find_or_create_database_authentication

    [
      {:name => "RABBITMQ_USER_NAME",    :value => rabbit_auth.userid},
      {:name => "DATABASE_SERVICE_NAME", :value => ENV["POSTGRESQL_SERVICE_HOST"]},
      {:name => "POSTGRESQL_DATABASE",   :value => "awx"},
      {:name => "POSTGRESQL_USER",       :value => database_auth.userid},
      {:name      => "ANSIBLE_SECRET_KEY",
       :valueFrom => {:secretKeyRef=>{:name => ANSIBLE_SECRETS_NAME, :key => "secret-key"}}},
      {:name      => "ADMIN_PASSWORD",
       :valueFrom => {:secretKeyRef=>{:name => ANSIBLE_SECRETS_NAME, :key => "admin-password"}}},
      {:name      => "POSTGRESQL_PASSWORD",
       :valueFrom => {:secretKeyRef=>{:name => ANSIBLE_SECRETS_NAME, :key => "database-password"}}},
      {:name      => "RABBITMQ_PASSWORD",
       :valueFrom => {:secretKeyRef=>{:name => ANSIBLE_SECRETS_NAME, :key => "rabbit-password"}}}
    ]
  end

  def image
    "#{settings.image_name}:#{settings.image_tag}"
  end

  def orchestrator
    @orchestrator ||= ContainerOrchestrator.new
  end

  def settings
    ::Settings.embedded_ansible.container
  end
end
