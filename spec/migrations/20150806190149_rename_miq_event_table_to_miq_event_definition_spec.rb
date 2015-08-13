require 'spec_helper'
require Rails.root.join('db/migrate/20150806190149_rename_miq_event_table_to_miq_event_definition')

describe RenameMiqEventTableToMiqEventDefinition do
  migration_context :up do
    let(:miq_set_stub)          { migration_stub(:MiqSet) }
    let(:relationship_stub)     { migration_stub(:Relationship) }
    let(:pending_change_stub)   { migration_stub(:RrPendingChange) }
    let(:sync_state_stub)       { migration_stub(:RrSyncState) }

    it 'renames MiqEventSet to MiqEventDefinitionSet in miq_sets' do
      changed = miq_set_stub.create!(:set_type => 'MiqEventSet')
      ignored = miq_set_stub.create!(:set_type => 'SomeOtherSet')

      migrate

      expect(changed.reload.set_type).to eq('MiqEventDefinitionSet')
      expect(ignored.reload.set_type).to eq('SomeOtherSet')
    end

    it 'renames MiqEvent/Set to MiqEventDefinition/Set in relationships' do
      changed_event = relationship_stub.create!(:resource_type => 'MiqEvent')
      changed_set   = relationship_stub.create!(:resource_type => 'MiqEventSet')
      ignored       = relationship_stub.create!(:resource_type => 'SomeOtherType')

      migrate

      expect(changed_event.reload.resource_type).to eq('MiqEventDefinition')
      expect(changed_set.reload.resource_type).to eq('MiqEventDefinitionSet')
      expect(ignored.reload.resource_type).to eq('SomeOtherType')
    end

    context "renames miq_events to miq_event_definitions" do
      before do
        pending_change_stub.create_table
        sync_state_stub.create_table
      end

      it "in rr#_pending_changes tables" do
        changed = pending_change_stub.create!(:change_table => "miq_events")
        ignored = pending_change_stub.create!(:change_table => "some_other_table")

        migrate

        expect(changed.reload.change_table).to eq("miq_event_definitions")
        expect(ignored.reload.change_table).to eq("some_other_table")
      end

      it "in rr#_sync_states tables" do
        changed = sync_state_stub.create!(:table_name => "miq_events")
        ignored = sync_state_stub.create!(:table_name => "some_other_table")

        migrate

        expect(changed.reload.table_name).to eq("miq_event_definitions")
        expect(ignored.reload.table_name).to eq("some_other_table")
      end
    end
  end

  migration_context :down do
    let(:miq_set_stub)          { migration_stub(:MiqSet) }
    let(:relationship_stub)     { migration_stub(:Relationship) }
    let(:pending_change_stub)   { migration_stub(:RrPendingChange) }
    let(:sync_state_stub)       { migration_stub(:RrSyncState) }

    it 'renames MiqEventDefinitionSet to MiqEventSet in miq_sets' do
      changed = miq_set_stub.create!(:set_type => 'MiqEventDefinitionSet')
      ignored = miq_set_stub.create!(:set_type => 'SomeOtherSet')

      migrate

      expect(changed.reload.set_type).to eq('MiqEventSet')
      expect(ignored.reload.set_type).to eq('SomeOtherSet')
    end

    it 'renames MiqEventDefinition/Set to MiqEvent/Set in relationships' do
      changed_event = relationship_stub.create!(:resource_type => 'MiqEventDefinition')
      ignored       = relationship_stub.create!(:resource_type => 'SomeOtherType')

      migrate

      expect(changed_event.reload.resource_type).to eq('MiqEvent')
      expect(ignored.reload.resource_type).to eq('SomeOtherType')
    end

    it 'renames MiqEventDefinitionSet to MiqEventSet in relationships' do
      changed = relationship_stub.create!(:resource_type => 'MiqEventDefinitionSet')

      migrate

      expect(changed.reload.resource_type).to eq('MiqEventSet')
    end

    context "renames miq_event_definitions to miq_events" do
      before do
        pending_change_stub.create_table
        sync_state_stub.create_table
      end

      it "in rr#_pending_changes tables" do
        changed = pending_change_stub.create!(:change_table => "miq_event_definitions")
        ignored = pending_change_stub.create!(:change_table => "some_other_table")

        migrate

        expect(changed.reload.change_table).to eq("miq_events")
        expect(ignored.reload.change_table).to eq("some_other_table")
      end

      it "in rr#_sync_states tables" do
        changed = sync_state_stub.create!(:table_name => "miq_event_definitions")
        ignored = sync_state_stub.create!(:table_name => "some_other_table")

        migrate

        expect(changed.reload.table_name).to eq("miq_events")
        expect(ignored.reload.table_name).to eq("some_other_table")
      end
    end
  end
end
