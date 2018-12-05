require_migration

describe RemoveRenamedAnsibleTowerConfigurationManagerRefreshWorkerRows do
  migration_context :up do
    let(:miq_worker) { migration_stub(:MiqWorker) }

    it "deletes ansible tower configuration manager refresh workers" do
      miq_worker.create!(:type => "MiqWorker")
      miq_worker.create!(:type => "ManageIQ::Providers::AnsibleTower::ConfigurationManager::RefreshWorker")

      migrate

      expect(miq_worker.count).to      eq(1)
      expect(miq_worker.first.type).to eq("MiqWorker")
    end
  end
end
