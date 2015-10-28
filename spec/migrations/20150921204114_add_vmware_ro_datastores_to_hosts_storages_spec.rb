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
      seq_start = ActiveRecord::Base.rails_sequence_start
      seq_start = 1 if seq_start == 0

      h = hosts_storages_stub.create(:host_id => 1, :storage_id => 2)
      migrate
      h = host_storages_stub.first

      expect(h.id).to eq(seq_start)
    end
    it "Maintains host_id after rename" do
      h = hosts_storages_stub.create(:host_id => 1, :storage_id => 2)
      migrate
      h = host_storages_stub.first

      expect(h.host_id).to eq(1)
    end
    it "Maintains storage_id after rename" do
      h = hosts_storages_stub.create(:host_id => 1, :storage_id => 2)
      migrate
      h = host_storages_stub.first

      expect(h.storage_id).to eq(2)
    end
  end
end
