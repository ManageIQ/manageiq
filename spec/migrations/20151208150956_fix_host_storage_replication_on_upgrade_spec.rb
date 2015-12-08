require "spec_helper"
require_migration

describe FixHostStorageReplicationOnUpgrade do
  let(:pending_change_stub) { migration_stub(:RrPendingChange) }
  let(:sync_state_stub)     { migration_stub(:RrSyncState) }
  let(:region_stub)         { migration_stub(:MiqRegion) }
  let(:host_storage_stub)   { migration_stub(:HostsStorage) }

  migration_context :up do
    before do
      region_stub.create!(:id => 1_000_000_000_001, :region => 1)
    end

    context "on a replication target" do
      it "removes all the host_storages records" do
        region_stub.create!(:id => 99_000_000_000_001, :region => 99)
        host_storage_stub.create!(:id => 1_000_000_000_001, :storage_id => 1, :host_id => 1)
        host_storage_stub.create!(:id => 2_000_000_000_001, :storage_id => 1, :host_id => 2)

        migrate

        expect(host_storage_stub.count).to eq 0
      end
    end

    context "on a replication source" do
      before do
        pending_change_stub.create_table
        sync_state_stub.create_table
      end

      it "reinstalls replication for the new table name" do
        pending_change_stub.create!(:change_table => "hosts_storages")
        sync_state_stub.create!(:table_name => "hosts_storages")
        task = double
        expect(Rake::Task).to receive(:[]).with("evm:dbsync:prepare_replication_without_sync").and_return(task)
        expect(task).to receive(:invoke)

        migrate

        expect(pending_change_stub.where(:change_table => "hosts_storages").count).to eq 0
        expect(sync_state_stub.where(:table_name => "hosts_storages").count).to eq 0
      end
    end
  end
end
