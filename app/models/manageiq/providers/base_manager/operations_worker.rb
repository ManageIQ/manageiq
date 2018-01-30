class ManageIQ::Providers::BaseManager::OperationsWorker < MiqWorker
  require_nested :Runner

  include PerEmsWorkerMixin

  self.required_roles = "ems_operations"

  def friendly_name
    @friendly_name ||= begin
      ems = ext_management_system
      if ems.nil?
        queue_name.titleize
      else
        _("Operations Worker for Provider: %{name}") % {:name => ems.name}
      end
    end
  end

  def self.ems_class
    parent
  end

  def self.normalized_type
    @normalized_type ||= "ems_operations_worker"
  end

  def self.uri(ems)
    worker = find_by_ems(ems).where(MiqWorker::CONDITION_CURRENT).first
    if worker.nil?
      _log.warn("No active EMS Operations Worker found")
      return nil
    end

    if worker.uri.blank?
      _log.warn("EMS Operations Worker URI is blank")
      return nil
    end

    worker.uri
  end

  def self.connect_params(_ems)
    raise NotImplementedError, _("must be implemented in subclass")
  end
end
