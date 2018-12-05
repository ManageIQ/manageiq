class RemoveRenamedAnsibleTowerConfigurationManagerRefreshWorkerRows < ActiveRecord::Migration[5.0]
  class MiqWorker < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    # Was renamed to ManageIQ::Providers::AnsibleTower::AutomationManager::RefreshWorker in 2f0ef1a90758f2
    MiqWorker.where(:type => "ManageIQ::Providers::AnsibleTower::ConfigurationManager::RefreshWorker").delete_all
  end
end
