class OpenstackAmqpEvent
  attr_accessor :payload, :metadata

  def initialize(payload, metadata)
    @payload = payload
    @metadata = metadata
  end
end
