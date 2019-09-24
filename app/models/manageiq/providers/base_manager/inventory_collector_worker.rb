class ManageIQ::Providers::BaseManager::InventoryCollectorWorker < MiqWorker
  require_nested :Runner

  include PerEmsWorkerMixin

  self.required_roles = "ems_inventory"

  def self.has_required_role?
    return false if worker_settings[:disabled]
    super
  end

  def friendly_name
    @friendly_name ||= begin
      ems = ext_management_system
      if ems.nil?
        queue_name.titleize
      else
        _("Inventory Collector for Provider: %{name}") % {:name => ems.name}
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
