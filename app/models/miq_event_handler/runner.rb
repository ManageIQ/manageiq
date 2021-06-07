class MiqEventHandler::Runner < MiqQueueWorkerBase::Runner
  def self.miq_messaging_service
    "manageiq.ems-events"
  end

  def deliver_message(msg)
    return process_miq_messaging_message(msg) if msg.kind_of?(ManageIQ::Messaging::ReceivedMessage)

    super
  end

  def process_miq_messaging_message(msg)
    EmsEvent.add(msg.sender, msg.payload.deep_symbolize_keys)
  end
end
