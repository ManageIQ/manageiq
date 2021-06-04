class MiqEventHandler::Runner < MiqQueueWorkerBase::Runner
  def self.kafka_service
    "manageiq.ems-events"
  end
end
