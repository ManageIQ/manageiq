require_migration

RSpec.describe UpdatePersistentVolumesParentType do
  migration_context :up do
    it "updates container volumes with 'ManageIQ::Providers::ContainerManager' parent_type to 'ExtManagementSystem'" do
      pv = migration_stub(:ContainerVolume).create!(:parent_type => 'ManageIQ::Providers::ContainerManager')
      cv = migration_stub(:ContainerVolume).create!(:parent_type => 'ContainerGroup')

      migrate

      expect(pv.reload.parent_type).to eq('ExtManagementSystem')
      expect(cv.reload.parent_type).to eq('ContainerGroup')
    end
  end

  migration_context :down do
    it "updates container volumes with 'ExtManagementSystem' parent_type to 'ManageIQ::Providers::ContainerManager'" do
      pv = migration_stub(:ContainerVolume).create!(:parent_type => 'ExtManagementSystem')
      cv = migration_stub(:ContainerVolume).create!(:parent_type => 'ContainerGroup')

      migrate

      expect(pv.reload.parent_type).to eq('ManageIQ::Providers::ContainerManager')
      expect(cv.reload.parent_type).to eq('ContainerGroup')
    end
  end
end
