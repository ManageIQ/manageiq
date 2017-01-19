class ManageIQ::Providers::AnsibleTower::AutomationManager::RefreshWorker::Collector
  def initialize(ems, _options = nil)
    @ems        = ems
    @connection = ems.connect
  end

  def inventories
    @connection.api.inventories.all
  end

  def hosts
    @connection.api.hosts.all
  end

  def job_templates
    @connection.api.job_templates.all
  end
end
