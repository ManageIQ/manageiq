require_migration

describe StiConfigurationScript do
  migration_context :up do
    let(:configuration_script_stub) { migration_stub(:ConfigurationScript) }

    it "sets type" do
      cs = configuration_script_stub.create!

      migrate

      expect(cs.reload.type).to eq("ManageIQ::Providers::AnsibleTower::ConfigurationManager::ConfigurationScript")
    end
  end
end
