require_migration

describe UpgradeHostStorageFromReserved do
  let(:reserve_stub)      { Spec::Support::MigrationStubs.reserved_stub }
  let(:host_storage_stub) { migration_stub(:HostStorage) }

  migration_context :up do
    it "Migrates Reserves data to HostStorage" do
      hs = host_storage_stub.create!
      reserve_stub.create!(
        :resource_type => "HostStorage",
        :resource_id   => hs.id,
        :reserved      => {
          :ems_ref => "datastore-1"
        }
      )

      migrate

      hs.reload

      expect(reserve_stub.count).to eq(0)
      expect(hs.ems_ref).to eq("datastore-1")
    end
  end

  migration_context :down do
    it "Migrates ems_ref in HostStorage to Reserves table" do
      host    = FactoryGirl.create(:host)
      storage = FactoryGirl.create(:storage)

      hs = host_storage_stub.create!(
        :host_id    => host.id,
        :storage_id => storage.id,
        :ems_ref    => "datastore-1"
      )

      migrate

      r = reserve_stub.first

      expect(reserve_stub.count).to eq(1)
      expect(r.resource_id).to   eq(hs.id)
      expect(r.resource_type).to eq("HostStorage")
      expect(r.reserved).to      eq(:ems_ref => "datastore-1")
    end
  end
end
