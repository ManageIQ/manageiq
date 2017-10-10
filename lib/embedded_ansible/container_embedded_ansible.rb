class ContainerEmbeddedAnsible < EmbeddedAnsible
  def self.available?
    ContainerOrchestrator.available?
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
