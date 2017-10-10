class ContainerEmbeddedAnsible < EmbeddedAnsible
  ANSIBLE_DC_NAME = "ansible".freeze

  def self.available?
    ContainerOrchestrator.available?
  end

  def start
    miq_database.set_ansible_admin_authentication(:password => ENV["ANSIBLE_ADMIN_PASSWORD"])
    ContainerOrchestrator.new.scale(ANSIBLE_DC_NAME, 1)

    loop do
      break if alive?

      _log.info("Waiting for Ansible container to respond")
      sleep WAIT_FOR_ANSIBLE_SLEEP
    end
  end

  def stop
    ContainerOrchestrator.new.scale(ANSIBLE_DC_NAME, 0)
  end

  alias disable stop

  def running?
    true
  end

  def configured?
    true
  end

  def api_connection
  end
end
