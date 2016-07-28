require_migration

describe RemoveDatabaseSynchronizationRole do
  let(:server_role_stub)     { migration_stub(:ServerRole) }
  let(:assigned_role_stub)   { migration_stub(:AssignedServerRole) }
  let(:settings_change_stub) { migration_stub(:SettingsChange) }

  let(:role_name) { "database_synchronization" }

  migration_context :up do
    it "removes the server role" do
      role = server_role_stub.create!(:name => role_name)
      assigned_role_stub.create!(:server_role_id => role.id)

      migrate

      expect(server_role_stub.where(:name => role_name)).to be_empty
      expect(assigned_role_stub.where(:server_role_id => role.id)).to be_empty
    end

    it "removes the role from currently configured servers" do
      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :key           => "/server/role",
        :value         => "database_operations,event,reporting,scheduler,#{role_name}"
      )

      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :key           => "/server/role",
        :value         => "ems_operations,ems_inventory,#{role_name},user_interface"
      )

      migrate

      settings_change_stub.where(:key => "/server/role").each do |change|
        expect(change.value).to_not include(role_name)
      end
    end
  end
end
