require_migration

describe AddVmwareRoDatastoresToHostsStorages do
  let(:host_storages_stub) { migration_stub(:HostStorage) }

  migration_context :up do
    it "Adds ID in correct region" do
      migrate
    end
  end
end
