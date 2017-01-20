class ManageIQ::Providers::AnsibleTower::ConfigurationManager::RefreshWorker::Collector
  def initialize(ems, target, _options = nil)
    @ems        = ems
    @connection = ems.connect
    @target     = target
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
