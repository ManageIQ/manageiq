require_migration

describe AddEnabledFieldToEms do
  migration_context :up do
    let(:ext_management_system_stub) { migration_stub(:ExtManagementSystem) }

    it 'sets ExtManagementSystem.enabled to true by default' do
      ems = ext_management_system_stub.create!

      migrate

      ems.reload
      expect(ems.enabled).to be true
    end
  end
end
