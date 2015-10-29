require_migration

describe AddVmwareRoDatastoresToHostsStorages do
  class AddVmwareRoDatastoresToHostsStorages::HostsStorage < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
    self.table_name = "hosts_storages"
  end

  let(:host_storages_stub) { migration_stub(:HostStorage) }
  let(:hosts_storages_stub) { migration_stub(:HostsStorage) }

  migration_context :up do
    it "Adds ID in correct region" do
      seq_start = hosts_storages_stub.rails_sequence_start
      seq_start = 1 if seq_start == 0

      host_id = seq_start
      storage_id = seq_start + 1

      hosts_storages_stub.create(:host_id => host_id, :storage_id => storage_id)
      migrate
      h = host_storages_stub.first

      expect(host_storages_stub.id_to_region h.id).to eq(host_storages_stub.my_region_number)
    end

    it "Maintains host_id after rename" do
      seq_start = hosts_storages_stub.rails_sequence_start
      seq_start = 1 if seq_start == 0

      host_id = seq_start
      storage_id = seq_start + 1

      hosts_storages_stub.create(:host_id => host_id, :storage_id => storage_id)
      migrate
      h = host_storages_stub.first

      expect(h.host_id).to eq(host_id)
    end

    it "Maintains storage_id after rename" do
      seq_start = hosts_storages_stub.rails_sequence_start
      seq_start = 1 if seq_start == 0

      host_id = seq_start
      storage_id = seq_start + 1

      hosts_storages_stub.create(:host_id => host_id, :storage_id => storage_id)
      migrate
      h = host_storages_stub.first

      expect(h.storage_id).to eq(storage_id)
    end
  end
end
