class EmbeddedAnsible
  include Vmdb::Logging

  ANSIBLE_ROLE           = "embedded_ansible".freeze
  WAIT_FOR_ANSIBLE_SLEEP = 1.second

  def self.new
    require "ansible_tower_client"
    self == EmbeddedAnsible ? detect_available_platform.new : super
  end

  def self.detect_available_platform
    subclasses.detect(&:available?) || NullEmbeddedAnsible
  end

  def self.available?
    detect_available_platform != NullEmbeddedAnsible
  end

  def self.enabled?
    MiqServer.my_server(true).has_active_role?(ANSIBLE_ROLE)
  end

  def alive?
    return false unless configured? && running?
    begin
      api_connection.api.verify_credentials
    rescue AnsibleTowerClient::ClientError
      return false
    end
    true
  end

  private

  def api_connection_raw(host, port)
    admin_auth = miq_database.ansible_admin_authentication
    AnsibleTowerClient::Connection.new(
      :base_url   => URI::HTTP.build(:host => host, :path => "/api/v1", :port => port).to_s,
      :username   => admin_auth.userid,
      :password   => admin_auth.password,
      :verify_ssl => 0
    )
  end

  def miq_database
    MiqDatabase.first
  end
end

Dir.glob(File.join(File.dirname(__FILE__), "embedded_ansible/*.rb")).each { |f| require_dependency f }
