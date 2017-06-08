require "securerandom"
require "awesome_spawn"
require "linux_admin"
require "ansible_tower_client"

class EmbeddedAnsible
  ANSIBLE_ROLE           = "embedded_ansible".freeze
  SETUP_SCRIPT           = "ansible-tower-setup".freeze
  SECRET_KEY_FILE        = "/etc/tower/SECRET_KEY".freeze
  EXCLUDE_TAGS           = "packages,migrations,firewall".freeze
  HTTP_PORT              = 54_321
  HTTPS_PORT             = 54_322
  WAIT_FOR_ANSIBLE_SLEEP = 1.second

  def self.available?
    return false unless MiqEnvironment::Command.is_appliance?

    required_rpms = Set["ansible-tower-server", "ansible-tower-setup"]
    required_rpms.subset?(LinuxAdmin::Rpm.list_installed.keys.to_set)
  end

  def self.enabled?
    MiqServer.my_server(true).has_active_role?(ANSIBLE_ROLE)
  end

  def self.running?
    services.all? { |service| LinuxAdmin::Service.new(service).running? }
  end

  def self.configured?
    return false unless File.exist?(SECRET_KEY_FILE)
    key = miq_database.ansible_secret_key
    key.present? && key == File.read(SECRET_KEY_FILE)
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
    if configured?
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

  def self.stop
    services.each { |service| LinuxAdmin::Service.new(service).stop }
  end

  def self.disable
    services.each { |service| LinuxAdmin::Service.new(service).stop.disable }
  end

  def self.services
    AwesomeSpawn.run!("source /etc/sysconfig/ansible-tower; echo $TOWER_SERVICES").output.split
  end

  def self.api_connection
    admin_auth = miq_database.ansible_admin_authentication
    AnsibleTowerClient::Connection.new(
      :base_url => URI::HTTP.build(:host => "localhost", :path => "/api/v1", :port => HTTP_PORT).to_s,
      :username => admin_auth.userid,
      :password => admin_auth.password
    )
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
  rescue AwesomeSpawn::CommandResultError => e
    _log.error("EmbeddedAnsible setup script failed with: #{e.message}")
    miq_database.ansible_secret_key = nil
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
end
