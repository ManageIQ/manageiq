require "securerandom"
require "awesome_spawn"
require "linux_admin"
require "ansible_tower_client"
require "fileutils"

class EmbeddedAnsible
  include Vmdb::Logging

  ANSIBLE_ROLE           = "embedded_ansible".freeze
  HTTP_PORT              = 54_321
  HTTPS_PORT             = 54_322
  WAIT_FOR_ANSIBLE_SLEEP = 1.second
  ANSIBLE_DC_NAME        = "ansible".freeze

  def self.new
    self == EmbeddedAnsible ? detect_available_platform.new : super
  end

  def self.detect_available_platform
    subclasses.detect(&:available?) || NullEmbeddedAnsible
  end

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
  end

  def self.configured?
    return true if MiqEnvironment::Command.is_container?
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

  def self.api_connection
    if MiqEnvironment::Command.is_container?
      host = ENV["ANSIBLE_SERVICE_HOST"]
      port = ENV["ANSIBLE_SERVICE_PORT_HTTP"]
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

  def self.miq_database
    MiqDatabase.first
  end
  private_class_method :miq_database
end

Dir.glob(File.join(File.dirname(__FILE__), "embedded_ansible/*.rb")).each { |f| require_dependency f }
