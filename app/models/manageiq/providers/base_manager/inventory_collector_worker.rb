class ManageIQ::Providers::BaseManager::InventoryCollectorWorker < MiqWorker
  require_nested :Runner

  include PerEmsWorkerMixin

  self.required_roles = "ems_inventory"

  def self.has_required_role?
    !worker_settings[:disabled]
  end

  def friendly_name
    @friendly_name ||= begin
      ems = ext_management_system
      if ems.nil?
        queue_name.titleize
      else
        _("Inventory Collector for %{table}: %{name}") % {:table => ui_lookup(:table => "ext_management_systems"),
                                                          :name  => ems.name}
      end
    end
  end

  def self.ems_class
    parent
  end

  def self.normalized_type
    @normalized_type ||= "ems_inventory_collector_worker"
  end
end
