class ManageIQ::Providers::BaseManager::RefreshWorker < MiqQueueWorkerBase
  require_nested :Runner

  include PerEmsWorkerMixin

  # Don't allow multiple refresh workers to run at once
  self.include_stopping_workers_on_synchronize = true
  self.required_roles = "ems_inventory"

  def friendly_name
    @friendly_name ||= begin
      ems = ext_management_system
      if ems.nil?
        queue_name.kind_of?(Array) ? queue_name.collect(&:titleize).join(", ") : queue_name.titleize
      else
        _("Refresh Worker for Provider: %{name}") % {:name => ems.name}
      end
    end
  end

  def self.ems_class
    parent
  end

  def self.normalized_type
    @normalized_type ||= "ems_refresh_worker"
  end
end
