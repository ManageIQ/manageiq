require "awesome_spawn"
require "linux_admin"

class EmbeddedAnsible
  APPLIANCE_ANSIBLE_DIRECTORY = "/opt/ansible-installer".freeze
  ANSIBLE_ROLE                = "embedded_ansible".freeze
  SETUP_SCRIPT                = "#{APPLIANCE_ANSIBLE_DIRECTORY}/setup.sh".freeze

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

  def self.configure
    setup_params = {
      :e => "minimum_var_space=0",
      :k => "packages,migrations,supervisor"
    }
    AwesomeSpawn.run!(SETUP_SCRIPT, :params => setup_params)
  end

  def self.start
    setup_params = {
      :e => "minimum_var_space=0",
      :k => "packages,migrations"
    }
    AwesomeSpawn.run!(SETUP_SCRIPT, :params => setup_params)
  end

  def self.stop
    services.each { |service| LinuxAdmin::Service.new(service).stop.disable }
  end

  def self.services
    AwesomeSpawn.run!("source /etc/sysconfig/ansible-tower; echo $TOWER_SERVICES").output.split
  end
end
