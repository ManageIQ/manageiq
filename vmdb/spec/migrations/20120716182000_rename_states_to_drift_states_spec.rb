require "spec_helper"
require Rails.root.join("db/migrate/20120716182000_rename_states_to_drift_states.rb")

describe RenameStatesToDriftStates do
  migration_context :up do
    let(:pending_change_stub) { migration_stub(:RrPendingChange) }
    let(:sync_state_stub)     { migration_stub(:RrSyncState) }

    context "renames state to drift_state" do
      before do
        pending_change_stub.create_table
        sync_state_stub.create_table
      end

      it "in rr#_pending_changes tables" do
        changed = pending_change_stub.create!(:change_table => "state")
        ignored = pending_change_stub.create!(:change_table => "some_other_table")

        migrate

        changed.reload.change_table.should == "drift_state"
        ignored.reload.change_table.should == "some_other_table"
      end

      it "in rr#_sync_states tables" do
        changed = sync_state_stub.create!(:table_name => "state")
        ignored = sync_state_stub.create!(:table_name => "some_other_table")

        migrate

        changed.reload.table_name.should == "drift_state"
        ignored.reload.table_name.should == "some_other_table"
      end
    end
  end

  migration_context :down do
    let(:pending_change_stub) { migration_stub(:RrPendingChange) }
    let(:sync_state_stub)     { migration_stub(:RrSyncState) }

    context "renames drift_state to state" do
      before do
        pending_change_stub.create_table
        sync_state_stub.create_table
      end

      it "in rr#_pending_changes tables" do
        changed = pending_change_stub.create!(:change_table => "drift_state")
        ignored = pending_change_stub.create!(:change_table => "some_other_table")

        migrate

        changed.reload.change_table.should == "state"
        ignored.reload.change_table.should == "some_other_table"
      end

      it "in rr#_sync_states tables" do
        changed = sync_state_stub.create!(:table_name => "drift_state")
        ignored = sync_state_stub.create!(:table_name => "some_other_table")

        migrate

        changed.reload.table_name.should == "state"
        ignored.reload.table_name.should == "some_other_table"
      end
    end
  end
end
