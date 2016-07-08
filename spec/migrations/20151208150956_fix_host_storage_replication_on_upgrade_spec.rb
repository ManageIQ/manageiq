require_migration

describe FixHostStorageReplicationOnUpgrade do
  let(:region_stub)         { migration_stub(:MiqRegion) }
  let(:host_storage_stub)   { migration_stub(:HostsStorage) }

  migration_context :up do
    before do
      region_stub.create!(:id => 1_000_000_000_001, :region => 1)
    end

    it "removes all the host_storages records on a replication target" do
      region_stub.create!(:id => 99_000_000_000_001, :region => 99)
      host_storage_stub.create!(:id => 1_000_000_000_001, :storage_id => 1, :host_id => 1)
      host_storage_stub.create!(:id => 2_000_000_000_001, :storage_id => 1, :host_id => 2)

      migrate

      expect(host_storage_stub.count).to eq 0
    end
  end
end
