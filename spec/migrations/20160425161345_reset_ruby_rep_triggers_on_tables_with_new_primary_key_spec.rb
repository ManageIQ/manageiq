require_migration

describe ResetRubyRepTriggersOnTablesWithNewPrimaryKey do
  let(:pending_change_stub) { migration_stub(:RrPendingChange) }
  let(:sync_state_stub)     { migration_stub(:RrSyncState) }

  migration_context :up do
    before do
      pending_change_stub.create_table
      sync_state_stub.create_table
    end

    it "uninstalls replication for the tables with a new pk" do
      described_class::TABLES.each do |t|
        pending_change_stub.create!(:change_table => t)
        sync_state_stub.create!(:table_name => t)
      end

      migrate

      described_class::TABLES.each do |t|
        expect(pending_change_stub.where(:change_table => t).count).to eq 0
        expect(sync_state_stub.where(:table_name => t).count).to eq 0
      end
    end
  end
end
