require "securerandom"
require "awesome_spawn"
require "linux_admin"
require "ansible_tower_client"
require "fileutils"

class EmbeddedAnsible
  ANSIBLE_ROLE           = "embedded_ansible".freeze
  SETUP_SCRIPT           = "ansible-tower-setup".freeze
  SECRET_KEY_FILE        = "/etc/tower/SECRET_KEY".freeze
  EXCLUDE_TAGS           = "packages,migrations,firewall".freeze
  HTTP_PORT              = 54_321
  HTTPS_PORT             = 54_322
  WAIT_FOR_ANSIBLE_SLEEP = 1.second
  TOWER_VERSION_FILE     = "/var/lib/awx/.tower_version".freeze
  ANSIBLE_DC_NAME        = "ansible".freeze

  def self.available?
    return true if MiqEnvironment::Command.is_container?
    return false unless MiqEnvironment::Command.is_appliance?

    required_rpms = Set["ansible-tower-server", "ansible-tower-setup"]
    required_rpms.subset?(LinuxAdmin::Rpm.list_installed.keys.to_set)
  end

  def self.enabled?
    MiqServer.my_server(true).has_active_role?(ANSIBLE_ROLE)
  end

  def self.running?
    return true if MiqEnvironment::Command.is_container?
    services.all? { |service| LinuxAdmin::Service.new(service).running? }
  end

  def self.configured?
    return true if MiqEnvironment::Command.is_container?

    return false unless File.exist?(SECRET_KEY_FILE)
    return false unless setup_completed?

    key = miq_database.ansible_secret_key
    key.present? && key == File.read(SECRET_KEY_FILE)
  end

  def self.upgrade?
    local_tower_version != tower_rpm_version
  end

  def self.alive?
    return false unless configured? && running?
    begin
      api_connection.api.verify_credentials
    rescue AnsibleTowerClient::ClientError
      return false
    end
    true
  end

  def self.start
    MiqEnvironment::Command.is_container? ? container_start : appliance_start
  end

  def self.stop
    MiqEnvironment::Command.is_container? ? container_stop : appliance_stop
  end

  def self.disable
    MiqEnvironment::Command.is_container? ? container_stop : appliance_disable
  end

  def self.services
    AwesomeSpawn.run!("source /etc/sysconfig/ansible-tower; echo $TOWER_SERVICES").output.split
  end

  def self.api_connection
    if MiqEnvironment::Command.is_container?
      host = ENV["ANSIBLE_SERVICE_NAME"]
      port = 80
    else
      host = "localhost"
      port = HTTP_PORT
    end

    admin_auth = miq_database.ansible_admin_authentication
    AnsibleTowerClient::Connection.new(
      :base_url   => URI::HTTP.build(:host => host, :path => "/api/v1", :port => port).to_s,
      :username   => admin_auth.userid,
      :password   => admin_auth.password,
      :verify_ssl => 0
    )
  end

  def self.appliance_start
    if configured? && !upgrade?
      services.each { |service| LinuxAdmin::Service.new(service).start.enable }
    else
      configure_secret_key
      run_setup_script(EXCLUDE_TAGS)
    end

    5.times do
      return if alive?

      _log.info("Waiting for EmbeddedAnsible to respond")
      sleep WAIT_FOR_ANSIBLE_SLEEP
    end

    raise "EmbeddedAnsible service is not responding after setup"
  end
  private_class_method :appliance_start

  def self.appliance_stop
    services.each { |service| LinuxAdmin::Service.new(service).stop }
  end
  private_class_method :appliance_stop

  def self.appliance_disable
    services.each { |service| LinuxAdmin::Service.new(service).stop.disable }
  end
  private_class_method :appliance_disable

  def self.container_start
    miq_database.set_ansible_admin_authentication(:password => ENV["ANSIBLE_ADMIN_PASSWORD"])
    ContainerOrchestrator.new.scale(ANSIBLE_DC_NAME, 1)

    loop do
      break if alive?

      _log.info("Waiting for Ansible container to respond")
      sleep WAIT_FOR_ANSIBLE_SLEEP
    end
  end
  private_class_method :container_start

  def self.container_stop
    ContainerOrchestrator.new.scale(ANSIBLE_DC_NAME, 0)
  end

  def self.run_setup_script(exclude_tags)
    json_extra_vars = {
      :minimum_var_space  => 0,
      :http_port          => HTTP_PORT,
      :https_port         => HTTPS_PORT,
      :tower_package_name => "ansible-tower-server"
    }.to_json

    with_inventory_file do |inventory_file_path|
      params = {
        "--"         => nil,
        :extra_vars= => json_extra_vars,
        :inventory=  => inventory_file_path,
        :skip_tags=  => exclude_tags
      }
      AwesomeSpawn.run!(SETUP_SCRIPT, :params => params)
    end
    write_setup_complete_file
  rescue AwesomeSpawn::CommandResultError => e
    _log.error("EmbeddedAnsible setup script failed with: #{e.message}")
    miq_database.ansible_secret_key = nil
    FileUtils.rm_f(setup_complete_file)
    raise
  end
  private_class_method :run_setup_script

  def self.with_inventory_file
    file = Tempfile.new("miq_inventory")
    begin
      file.write(inventory_file_contents)
      file.close
      yield(file.path)
    ensure
      file.unlink
    end
  end
  private_class_method :with_inventory_file

  def self.configure_secret_key
    key = miq_database.ansible_secret_key
    if key.present?
      File.write(SECRET_KEY_FILE, key)
    else
      AwesomeSpawn.run!("/usr/bin/python -c \"import uuid; file('#{SECRET_KEY_FILE}', 'wb').write(uuid.uuid4().hex)\"")
      miq_database.ansible_secret_key = File.read(SECRET_KEY_FILE)
    end
  end
  private_class_method :configure_secret_key

  def self.generate_admin_authentication
    miq_database.set_ansible_admin_authentication(:password => generate_password)
  end
  private_class_method :generate_admin_authentication

  def self.generate_rabbitmq_authentication
    miq_database.set_ansible_rabbitmq_authentication(:password => generate_password)
  end
  private_class_method :generate_rabbitmq_authentication

  def self.generate_database_authentication
    auth = miq_database.set_ansible_database_authentication(:password => generate_password)
    database_connection.select_value("CREATE ROLE #{database_connection.quote_column_name(auth.userid)} WITH LOGIN PASSWORD #{database_connection.quote(auth.password)}")
    database_connection.select_value("CREATE DATABASE awx OWNER #{database_connection.quote_column_name(auth.userid)} ENCODING 'utf8'")
    auth
  end
  private_class_method :generate_database_authentication

  def self.inventory_file_contents
    admin_auth    = miq_database.ansible_admin_authentication || generate_admin_authentication
    rabbitmq_auth = miq_database.ansible_rabbitmq_authentication || generate_rabbitmq_authentication
    database_auth = miq_database.ansible_database_authentication || generate_database_authentication
    db_config     = Rails.configuration.database_configuration[Rails.env]

    <<-EOF.strip_heredoc
      [tower]
      localhost ansible_connection=local

      [database]

      [all:vars]
      admin_password='#{admin_auth.password}'

      pg_host='#{db_config["host"] || "localhost"}'
      pg_port='#{db_config["port"] || "5432"}'

      pg_database='awx'
      pg_username='#{database_auth.userid}'
      pg_password='#{database_auth.password}'

      rabbitmq_port=5672
      rabbitmq_vhost=tower
      rabbitmq_username='#{rabbitmq_auth.userid}'
      rabbitmq_password='#{rabbitmq_auth.password}'
      rabbitmq_cookie=cookiemonster
      rabbitmq_use_long_name=false
      rabbitmq_enable_manager=false
    EOF
  end
  private_class_method :inventory_file_contents

  def self.miq_database
    MiqDatabase.first
  end
  private_class_method :miq_database

  def self.generate_password
    SecureRandom.base64(18).tr("+/", "-_")
  end
  private_class_method :generate_password

  def self.database_connection
    ActiveRecord::Base.connection
  end
  private_class_method :database_connection

  def self.local_tower_version
    File.read(TOWER_VERSION_FILE).strip
  end
  private_class_method :local_tower_version

  def self.tower_rpm_version
    LinuxAdmin::Rpm.info("ansible-tower-server")["version"]
  end
  private_class_method :tower_rpm_version

  def self.write_setup_complete_file
    FileUtils.touch(setup_complete_file)
  end
  private_class_method :write_setup_complete_file

  def self.setup_completed?
    File.exist?(setup_complete_file)
  end
  private_class_method :setup_completed?

  def self.setup_complete_file
    Rails.root.join("tmp", "embedded_ansible_setup_complete")
  end
  private_class_method :setup_complete_file
end
