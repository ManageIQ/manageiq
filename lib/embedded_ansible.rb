class EmbeddedAnsible
  APPLIANCE_ANSIBLE_DIRECTORY = "/opt/ansible-installer".freeze
  ANSIBLE_ROLE                = "embedded_ansible".freeze

  def self.available?
    path = ENV["APPLIANCE_ANSIBLE_DIRECTORY"] || APPLIANCE_ANSIBLE_DIRECTORY
    Dir.exist?(File.expand_path(path.to_s))
  end

  def self.enabled?
    MiqServer.my_server(true).has_active_role?(ANSIBLE_ROLE)
  end

  def self.running?
    # TODO
    false
  end
end
