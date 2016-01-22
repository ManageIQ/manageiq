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
        _("Event Monitor for %{table}: %{name}") % {:table => ui_lookup(:table => "ext_management_systems"),
                                                    :name  => ems.name}
      end
    end
  end

  def self.ems_class
    parent
  end
end
