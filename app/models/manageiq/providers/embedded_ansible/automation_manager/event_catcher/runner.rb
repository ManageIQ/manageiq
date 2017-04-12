class ManageIQ::Providers::EmbeddedAnsible::AutomationManager::EventCatcher::Runner < ManageIQ::Providers::BaseManager::EventCatcher::Runner
  include ManageIQ::Providers::AnsibleTower::Shared::AutomationManager::EventCatcher::Runner

  def start_event_monitor
    tid = super
    return tid unless tid.nil?

    # Get a new copy of the ems record in case the embedded ansible role changed servers
    @ems.reload
    nil
  end
end
