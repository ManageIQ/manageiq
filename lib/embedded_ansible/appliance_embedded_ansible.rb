require 'linux_admin'

class ApplianceEmbeddedAnsible < EmbeddedAnsible
  def self.available?
    return false unless MiqEnvironment::Command.is_appliance?
    required_rpms = Set["ansible-tower-server", "ansible-tower-setup"]
    required_rpms.subset?(LinuxAdmin::Rpm.list_installed.keys.to_set)
  end

  def start
  end

  def stop
  end

  def disable
  end

  def running?
  end

  def configured?
  end

  def api_connection
  end
end
