class ManageIQ::Providers::BaseManager::EventCatcher < MiqWorker
  include ProviderWorkerMixin
  include PerEmsWorkerMixin

  self.required_roles = ["event"]
  self.rails_worker = -> { !worker_settings.key?(:rails_worker) || worker_settings[:rails_worker] }

  def self.worker_settings_paths
    [[:ems, :"ems_#{module_parent.ems_type}"]]
  end

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
