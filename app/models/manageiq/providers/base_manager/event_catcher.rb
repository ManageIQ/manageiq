class ManageIQ::Providers::BaseManager::EventCatcher < MiqWorker
  require_nested :Runner

  include PerEmsWorkerMixin

  self.required_roles = ["event"]

  def friendly_name
    @friendly_name ||= begin
      ems = ext_management_system
      if ems.nil?
        queue_name.titleize
      else
        _("Event Monitor for Provider: %{name}") % {:name => ems.name}
      end
    end
  end

  def self.kill_priority
    MiqWorkerType::KILL_PRIORITY_EVENT_CATCHERS
  end
end
