require_migration

describe MigrateConfigurationScriptToBase do
  let(:service_resource_stub) { migration_stub(:ServiceResource) }

  migration_context :up do
    it 'migrates service_resources configuration_script to configuration_script_base' do
      resource = service_resource_stub.create!(
        :resource_type => 'ConfigurationScript'
      )

      migrate

      expect(resource.reload.resource_type).to eq('ConfigurationScriptBase')
    end

    it 'will not migrate service_resources records other than that of configuration_scripts' do
      resource = service_resource_stub.create!(:resource_type => 'SomeThing')

      migrate

      expect(resource.reload.resource_type).to eq('SomeThing')
    end
  end

  migration_context :down do
    it 'migrates service_resources configuration_script_base to configuration_script' do
      resource = service_resource_stub.create!(
        :resource_type => 'ConfigurationScriptBase'
      )

      migrate

      expect(resource.reload.resource_type).to eq('ConfigurationScript')
    end
  end
end
