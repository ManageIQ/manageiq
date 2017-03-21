class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::EventCatcher::Stream
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::EventCatcher::Stream

  class ProviderUnreachable < ManageIQ::Providers::BaseManager::EventCatcher::Runner::TemporaryFailure
  end

  def initialize(ems, options = {})
    @ems = ems
    @last_activity = nil
    @stop_polling = false
    @poll_sleep = options[:poll_sleep] || 20.seconds
  end
end
