require "awesome_spawn"
require "fileutils"
require "securerandom"

class ApplianceEmbeddedAnsible < EmbeddedAnsible
  TOWER_VERSION_FILE                    = "/var/lib/awx/.tower_version".freeze
  SETUP_SCRIPT                          = "ansible-tower-setup".freeze
  SECRET_KEY_FILE                       = "/etc/tower/SECRET_KEY".freeze
  SETTINGS_FILE                         = "/etc/tower/settings.py".freeze
  EXCLUDE_TAGS                          = "packages,migrations,firewall".freeze
  HTTP_PORT                             = 54_321
  HTTPS_PORT                            = 54_322
  CONSOLIDATED_PLUGIN_PLAYBOOKS_TEMPDIR = Pathname.new("/var/lib/awx_consolidated_source").freeze

  def self.available?
    require "linux_admin"
    return false unless MiqEnvironment::Command.is_appliance?
    required_rpms = Set["ansible-tower-server", "ansible-tower-setup"]
    required_rpms.subset?(LinuxAdmin::Rpm.list_installed.keys.to_set)
  end

  def self.priority
    30
  end

  def initialize
    super
    require "linux_admin"
  end

  def start
    if run_setup_script?
      configure_secret_key
      run_setup_script(EXCLUDE_TAGS)
    else
      update_proxy_settings
      services.each { |service| LinuxAdmin::Service.new(service).start.enable }
    end

    5.times do
      return if alive?

      _log.info("Waiting for EmbeddedAnsible to respond")
      sleep WAIT_FOR_ANSIBLE_SLEEP
    end

    raise "EmbeddedAnsible service is not responding after setup"
  end

  def stop
    services.each { |service| LinuxAdmin::Service.new(service).stop }
  end

  def disable
    services.each { |service| LinuxAdmin::Service.new(service).stop.disable }
  end

  def running?
    services.all? { |service| LinuxAdmin::Service.new(service).running? }
  end

  def configured?
    return false unless File.exist?(SECRET_KEY_FILE)
    return false unless setup_completed?

    key = miq_database.ansible_secret_key
    key.present? && key == File.read(SECRET_KEY_FILE)
  end

  def api_connection
    api_connection_raw("localhost", HTTP_PORT)
  end

  def create_local_playbook_repo
    self.class.consolidate_plugin_playbooks(playbook_repo_path)

    Dir.chdir(playbook_repo_path) do
      require 'rugged'
      repo = Rugged::Repository.init_at(".")
      index = repo.index
      index.add_all("*")
      index.write

      options              = {}
      options[:tree]       = index.write_tree(repo)
      options[:author]     = options[:committer] = { :email => "system@localhost", :name => "System", :time => Time.now.utc }
      options[:message]    = "Initial Commit"
      options[:parents]    = []
      options[:update_ref] = 'HEAD'
      Rugged::Commit.create(repo, options)
    end

    FileUtils.chown_R('awx', 'awx', playbook_repo_path)
  end

  def playbook_repo_path
    CONSOLIDATED_PLUGIN_PLAYBOOKS_TEMPDIR
  end

  private

  def run_setup_script?
    force_setup_run? || !configured? || upgrade?
  end

  def upgrade?
    local_tower_version != tower_rpm_version
  end

  def services
    AwesomeSpawn.run!("source /etc/sysconfig/ansible-tower; echo $TOWER_SERVICES").output.split
  end

  def run_setup_script(exclude_tags)
    json_extra_vars = {
      :awx_install_memcached_bind => MiqMemcached.server_address,
      :minimum_var_space          => 0,
      :http_port                  => HTTP_PORT,
      :https_port                 => HTTPS_PORT,
      :tower_package_name         => "ansible-tower-server"
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
    remove_force_setup_marker_file
  rescue AwesomeSpawn::CommandResultError => e
    _log.error("EmbeddedAnsible setup script failed with: #{e.message}")
    miq_database.ansible_secret_key = nil
    FileUtils.rm_f(setup_complete_file)
    raise
  end

  def with_inventory_file
    file = Tempfile.new("miq_inventory")
    begin
      file.write(inventory_file_contents)
      file.close
      yield(file.path)
    ensure
      file.unlink
    end
  end

  def configure_secret_key
    key = find_or_create_secret_key
    File.write(SECRET_KEY_FILE, key)
  end

  def update_proxy_settings
    current_contents = File.read(SETTINGS_FILE)
    new_contents = current_contents.gsub(/^.*AWX_TASK_ENV\['(HTTPS?_PROXY|NO_PROXY)'\].*$/, "")

    proxy_uri = VMDB::Util.http_proxy_uri(:embedded_ansible) || VMDB::Util.http_proxy_uri
    if proxy_uri
      new_contents << "\n" unless new_contents.end_with?("\n")
      new_contents << "AWX_TASK_ENV['HTTP_PROXY'] = '#{proxy_uri}'\n"
      new_contents << "AWX_TASK_ENV['HTTPS_PROXY'] = '#{proxy_uri}'\n"
      new_contents << "AWX_TASK_ENV['NO_PROXY'] = '127.0.0.1'\n"
    end
    File.write(SETTINGS_FILE, new_contents)
  end

  def inventory_file_contents
    admin_auth    = find_or_create_admin_authentication
    rabbitmq_auth = find_or_create_rabbitmq_authentication
    database_auth = find_or_create_database_authentication

    <<-EOF.strip_heredoc
      [tower]
      localhost ansible_connection=local

      [database]

      [all:vars]
      admin_password='#{admin_auth.password}'

      pg_host='#{database_configuration["host"] || "localhost"}'
      pg_port='#{database_configuration["port"] || "5432"}'

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

  def local_tower_version
    File.read(TOWER_VERSION_FILE).strip
  end

  def tower_rpm_version
    LinuxAdmin::Rpm.info("ansible-tower-server")["version"]
  end

  def write_setup_complete_file
    FileUtils.touch(setup_complete_file)
  end

  def setup_completed?
    File.exist?(setup_complete_file)
  end

  def setup_complete_file
    Rails.root.join("tmp", "embedded_ansible_setup_complete")
  end

  def remove_force_setup_marker_file
    FileUtils.rm_f(force_setup_run_marker_file)
  end

  def force_setup_run?
    File.exist?(force_setup_run_marker_file)
  end

  def force_setup_run_marker_file
    Rails.root.join("tmp", "embedded_ansible_force_setup_run")
  end
end
