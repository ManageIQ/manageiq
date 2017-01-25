require "securerandom"
require "awesome_spawn"
require "linux_admin"

class EmbeddedAnsible
  APPLIANCE_ANSIBLE_DIRECTORY = "/opt/ansible-installer".freeze
  ANSIBLE_ROLE                = "embedded_ansible".freeze
  SETUP_SCRIPT                = "#{APPLIANCE_ANSIBLE_DIRECTORY}/setup.sh".freeze
  SECRET_KEY_FILE             = "/etc/tower/SECRET_KEY".freeze
  CONFIGURE_EXCLUDE_TAGS      = "packages,migrations,firewall,supervisor".freeze
  START_EXCLUDE_TAGS          = "packages,migrations,firewall".freeze
  NGINX_HTTP_PORT             = "54321".freeze
  NGINX_HTTPS_PORT            = "54322".freeze

  def self.available?
    path = ENV["APPLIANCE_ANSIBLE_DIRECTORY"] || APPLIANCE_ANSIBLE_DIRECTORY
    Dir.exist?(File.expand_path(path.to_s))
  end

  def self.enabled?
    MiqServer.my_server(true).has_active_role?(ANSIBLE_ROLE)
  end

  def self.running?
    services.all? { |service| LinuxAdmin::Service.new(service).running? }
  end

  def self.configured?
    key = miq_database.ansible_secret_key
    key.present? && key == File.read(SECRET_KEY_FILE)
  end

  def self.configure
    configure_secret_key
    run_setup_script(playbook_extra_variables.merge(:k => CONFIGURE_EXCLUDE_TAGS))
    stop
  end

  def self.start
    run_setup_script(playbook_extra_variables.merge(:k => START_EXCLUDE_TAGS))
  end

  def self.stop
    services.each { |service| LinuxAdmin::Service.new(service).stop.disable }
  end

  def self.services
    AwesomeSpawn.run!("source /etc/sysconfig/ansible-tower; echo $TOWER_SERVICES").output.split
  end

  def self.playbook_extra_variables
    json_value = {
      :minimum_var_space => 0,
      :nginx_http_port   => NGINX_HTTP_PORT,
      :nginx_https_port  => NGINX_HTTPS_PORT
    }.to_json
    {:e => json_value}
  end
  private_class_method :playbook_extra_variables

  def self.run_setup_script(params)
    with_inventory_file do |inventory_file_path|
      AwesomeSpawn.run!(SETUP_SCRIPT, :params => params.merge(:i => inventory_file_path))
    end
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

  def self.generate_admin_password
    miq_database.ansible_admin_password = SecureRandom.hex
  end
  private_class_method :generate_admin_password

  def self.generate_rabbitmq_password
    miq_database.ansible_rabbitmq_password = SecureRandom.hex
  end
  private_class_method :generate_rabbitmq_password

  def self.generate_database_password
    password = SecureRandom.hex
    ApplicationRecord.connection.select_value("CREATE ROLE awx WITH LOGIN PASSWORD '#{password}'")
    ApplicationRecord.connection.select_value("CREATE DATABASE awx OWNER awx ENCODING 'utf8'")
    miq_database.ansible_database_password = password
  end
  private_class_method :generate_database_password

  def self.inventory_file_contents
    admin_password    = miq_database.ansible_admin_password || generate_admin_password
    rabbitmq_password = miq_database.ansible_rabbitmq_password || generate_rabbitmq_password
    database_password = miq_database.ansible_database_password || generate_database_password
    db_config         = Rails.configuration.database_configuration[Rails.env]

    <<-EOF.strip_heredoc
      [tower]
      localhost ansible_connection=local

      [database]

      [all:vars]
      admin_password='#{admin_password}'

      pg_host='#{db_config["host"] || "localhost"}'
      pg_port='#{db_config["port"] || "5432"}'

      pg_database='awx'
      pg_username='awx'
      pg_password='#{database_password}'

      rabbitmq_port=5672
      rabbitmq_vhost=tower
      rabbitmq_username=tower
      rabbitmq_password='#{rabbitmq_password}'
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
end
