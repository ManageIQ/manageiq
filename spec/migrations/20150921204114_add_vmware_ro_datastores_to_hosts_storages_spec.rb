require_migration

describe AddVmwareRoDatastoresToHostsStorages do
  let(:hosts_storages_stub) { migration_stub(:HostsStorage) }

  migration_context :up do
    it "Adds ID in correct region" do
      migrate
    end
  end
end
