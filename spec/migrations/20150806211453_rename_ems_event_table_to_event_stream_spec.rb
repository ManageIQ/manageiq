require 'spec_helper'
require Rails.root.join('db/migrate/20150806211453_rename_ems_event_table_to_event_stream')

describe RenameEmsEventTableToEventStream do
  let(:ems_event_stub)      { migration_stub(:EmsEvent) }
  let(:event_stream_stub)   { migration_stub(:EventStream) }
  let(:pending_change_stub) { migration_stub(:RrPendingChange) }
  let(:sync_state_stub)     { migration_stub(:RrSyncState) }

  migration_context :up do
    context 'renames table ems_evevnts to event_streams' do
      before do
        pending_change_stub.create_table
        sync_state_stub.create_table
      end

      it "in rr#_pending_changes tables" do
        changed = pending_change_stub.create!(:change_table => "ems_events")
        ignored = pending_change_stub.create!(:change_table => "some_other_table")

        migrate

        expect(changed.reload.change_table).to eq("event_streams")
        expect(ignored.reload.change_table).to eq("some_other_table")
      end

      it "in rr#_sync_states tables" do
        changed = sync_state_stub.create!(:table_name => "ems_events")
        ignored = sync_state_stub.create!(:table_name => "some_other_table")

        migrate

        expect(changed.reload.table_name).to eq("event_streams")
        expect(ignored.reload.table_name).to eq("some_other_table")
      end
    end

    it 'adds two cloumns' do
      ems_event_stub.create!

      migrate

      event_stream = event_stream_stub.first
      expect(event_stream.type).to eq('EmsEvent')
      expect(event_stream.target_id).to be_nil
    end
  end

  migration_context :down do
    it 'deletes two cloumns' do
      event_stream_stub.create!

      migrate

      event = ems_event_stub.first
      expect(event).not_to respond_to(:type)
      expect(event).not_to respond_to(:target_id)
    end

    context 'renames table event_streams to ems_events' do
      before do
        pending_change_stub.create_table
        sync_state_stub.create_table
      end

      it "in rr#_pending_changes tables" do
        changed = pending_change_stub.create!(:change_table => "event_streams")
        ignored = pending_change_stub.create!(:change_table => "some_other_table")

        migrate

        expect(changed.reload.change_table).to eq("ems_events")
        expect(ignored.reload.change_table).to eq("some_other_table")
      end

      it "in rr#_sync_states tables" do
        changed = sync_state_stub.create!(:table_name => "event_streams")
        ignored = sync_state_stub.create!(:table_name => "some_other_table")

        migrate

        expect(changed.reload.table_name).to eq("ems_events")
        expect(ignored.reload.table_name).to eq("some_other_table")
      end
    end
  end
end
