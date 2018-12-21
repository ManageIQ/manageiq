class DockerEmbeddedAnsible < EmbeddedAnsible
  AWX_WEB_PORT = "54321".freeze

  class DockerDaemon
    def initialize
      require 'linux_admin'
    end

    def start
      return unless Rails.env.production?
      LinuxAdmin::Service.new("docker").start.enable
    end

    def stop
      return unless Rails.env.production?
      LinuxAdmin::Service.new("docker").stop.disable
    end
  end

  private_constant :DockerDaemon

  def self.available?
    require 'docker'

    DockerDaemon.new.start
    Docker.validate_version!
  rescue
    false
  end

  def self.priority
    10
  end

  def initialize
    super
    require 'docker'
  end

  def start
    DockerDaemon.new.start
    run_rabbitmq_container
    run_memcached_container
    sleep(15)
    run_web_container
    run_task_container

    settings.setup_wait_seconds.times do
      break if alive?

      _log.info("Waiting for Ansible container to respond")
      sleep WAIT_FOR_ANSIBLE_SLEEP
    end
  rescue RuntimeError
    stop
  end

  def stop
    container_names.each { |c| stop_container(c) }
    DockerDaemon.new.stop
  end

  alias disable stop

  def running?
    container_names.all? { |c| container_running?(c) }
  end

  def configured?
    self.class.available?
  end

  def api_connection
    api_connection_raw("localhost", AWX_WEB_PORT)
  end

  def alive?
    super
  rescue JSON::ParserError
    false
  end

  private

  def run_rabbitmq_container
    rabbitmq_auth = find_or_create_rabbitmq_authentication
    run_container(
      rabbitmq_image_name,
      'name'         => rabbitmq_container_name,
      'ExposedPorts' => {"25672/tcp" => {},
                         "4369/tcp"  => {},
                         "5671/tcp"  => {},
                         "5672/tcp"  => {}},
      'Env'          => ["RABBITMQ_DEFAULT_VHOST=awx",
                         "RABBITMQ_DEFAULT_USER=#{rabbitmq_auth.userid}",
                         "RABBITMQ_DEFAULT_PASS=#{rabbitmq_auth.password}"]
    )
  end

  def run_memcached_container
    run_container(
      memcached_image_name,
      'name'         => memcached_container_name,
      'ExposedPorts' => {"11211/tcp" => {}}
    )
  end

  def run_web_container
    run_container(
      awx_web_image_name,
      'name'         => awx_web_container_name,
      'Env'          => awx_env,
      'Hostname'     => "awxweb",
      'User'         => "root",
      'ExposedPorts' => {"8052/tcp" => {}},
      'HostConfig'   => {
        'Links'        => [rabbitmq_container_name, memcached_container_name],
        'PortBindings' => {
          '8052/tcp' => [{ 'HostPort' => AWX_WEB_PORT, 'HostIp' => "0.0.0.0" }]
        }
      }
    )
  end

  def run_task_container
    run_container(
      awx_task_image_name,
      'name'         => awx_task_container_name,
      'Env'          => awx_env,
      'Hostname'     => "awx",
      'User'         => "root",
      'ExposedPorts' => {"8052/tcp" => {}},
      'HostConfig'   => {
        'Links' => [rabbitmq_container_name,
                    memcached_container_name,
                    awx_web_container_name]
      }
    )
  end

  def run_container(image, create_params = {})
    Docker::Image.create('fromImage' => image)
    container = Docker::Container.create(create_params.merge('Image' => image))
    container.start
  end

  def stop_container(name)
    Docker::Container.get(name).kill.delete
  rescue Docker::Error::NotFoundError
    nil
  end

  def container_running?(name)
    Docker::Container.get(name)
    true
  rescue Docker::Error::NotFoundError
    false
  end

  def awx_env
    admin_auth    = find_or_create_admin_authentication
    database_auth = find_or_create_database_authentication
    rabbitmq_auth = find_or_create_rabbitmq_authentication

    [
      "SECRET_KEY=#{find_or_create_secret_key}",
      "DATABASE_NAME=awx",
      "DATABASE_USER=#{database_auth.userid}",
      "DATABASE_PASSWORD=#{database_auth.password}",
      "DATABASE_PORT=#{database_configuration["port"] || 5432}",
      "DATABASE_HOST=#{database_host}",
      "RABBITMQ_USER=#{rabbitmq_auth.userid}",
      "RABBITMQ_PASSWORD=#{rabbitmq_auth.password}",
      "RABBITMQ_HOST=#{rabbitmq_container_name}",
      "RABBITMQ_PORT=5672",
      "RABBITMQ_VHOST=awx",
      "MEMCACHED_HOST=#{memcached_container_name}",
      "MEMCACHED_PORT=11211",
      "AWX_ADMIN_USER=#{admin_auth.userid}",
      "AWX_ADMIN_PASSWORD=#{admin_auth.password}"
    ]
  end

  def database_host
    db_host = database_configuration["host"]
    return db_host if db_host.presence && db_host != "localhost"

    MiqServer.my_server.ipaddress || docker_bridge_gateway
  end

  def docker_bridge_gateway
    br = Docker::Network.get("bridge")
    br.info["IPAM"]["Config"].first["Gateway"]
  end

  def container_names
    [
      awx_task_container_name,
      awx_web_container_name,
      memcached_container_name,
      rabbitmq_container_name
    ]
  end

  def awx_task_container_name
    "awx_task"
  end

  def awx_task_image_name
    "#{settings.task_image_name}:#{settings.task_image_tag}"
  end

  def awx_web_container_name
    "awx_web"
  end

  def awx_web_image_name
    "#{settings.web_image_name}:#{settings.web_image_tag}"
  end

  def rabbitmq_container_name
    "rabbitmq"
  end

  def rabbitmq_image_name
    "#{settings.rabbitmq_image_name}:#{settings.rabbitmq_image_tag}"
  end

  def memcached_container_name
    "memcached"
  end

  def memcached_image_name
    "#{settings.memcached_image_name}:#{settings.memcached_image_tag}"
  end

  def settings
    ::Settings.embedded_ansible.docker
  end
end
