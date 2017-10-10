class NullEmbeddedAnsible < EmbeddedAnsible
  def self.available?
    false
  end

  def start
    raise NotImplementedError, message
  end

  def stop
    raise NotImplementedError, message
  end

  def disable
    raise NotImplementedError, message
  end

  def running?
    raise NotImplementedError, message
  end

  def configured?
    raise NotImplementedError, message
  end

  def api_connection
    raise NotImplementedError, message
  end

  private

  def message
    "EmbeddedAnsible is not available on your current platform"
  end
end
