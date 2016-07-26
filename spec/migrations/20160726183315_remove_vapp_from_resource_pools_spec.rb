require_migration

describe RemoveVappFromResourcePools do
  let(:resource_pool_stub) { migration_stub(:ResourcePool) }

  migration_context :up do
    it 'migrates resource pools to vapps' do
      resource_pool = resource_pool_stub.create!(:name => "resource_pool", :vapp => false)
      vapp          = resource_pool_stub.create!(:name => "vapp", :vapp => true)

      migrate

      expect(resource_pool.reload).to have_attributes(:type => nil)
      expect(vapp.reload).to          have_attributes(:type => 'ManageIQ::Providers::Vmware::InfraManager::VirtualApp')
    end
  end

  migration_context :down do
    it 'migrates vapps to resource pools' do
      migrate
    end
  end
end
