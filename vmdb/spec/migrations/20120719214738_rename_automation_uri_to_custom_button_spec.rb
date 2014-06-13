require "spec_helper"
require Rails.root.join("db/migrate/20120719214738_rename_automation_uri_to_custom_button.rb")

describe RenameAutomationUriToCustomButton do
  migration_context :up do
    let(:miq_set_stub)        { migration_stub(:MiqSet) }
    let(:relationship_stub)   { migration_stub(:Relationship) }
    let(:pending_change_stub) { migration_stub(:RrPendingChange) }
    let(:sync_state_stub)     { migration_stub(:RrSyncState) }

    it "renames AutomationUriSet to CustomButtonSet in miq_sets" do
      changed = miq_set_stub.create!(:set_type => "AutomationUriSet", :guid => 'abc')
      ignored = miq_set_stub.create!(:set_type => "SomeOtherType",    :guid => 'def')

      migrate

      changed.reload.set_type.should == "CustomButtonSet"
      ignored.reload.set_type.should == "SomeOtherType"
    end

    it "renames AutomationUriSet to CustomButtonSet in relationships" do
      changed = relationship_stub.create!(:resource_type => "AutomationUriSet")
      ignored = relationship_stub.create!(:resource_type => "SomeOtherType")

      migrate

      changed.reload.resource_type.should == "CustomButtonSet"
      ignored.reload.resource_type.should == "SomeOtherType"
    end

    it "renames AutomationUri to CustomButton in relationships" do
      changed = relationship_stub.create!(:resource_type => "AutomationUri")
      ignored = relationship_stub.create!(:resource_type => "SomeOtherType")

      migrate

      changed.reload.resource_type.should == "CustomButton"
      ignored.reload.resource_type.should == "SomeOtherType"
    end

    context "renames automation_uris to custom_buttons" do
      before do
        pending_change_stub.create_table
        sync_state_stub.create_table
      end

      it "in rr#_pending_changes tables" do
        changed = pending_change_stub.create!(:change_table => "automation_uris")
        ignored = pending_change_stub.create!(:change_table => "some_other_table")

        migrate

        changed.reload.change_table.should == "custom_buttons"
        ignored.reload.change_table.should == "some_other_table"
      end

      it "in rr#_sync_states tables" do
        changed = sync_state_stub.create!(:table_name => "automation_uris")
        ignored = sync_state_stub.create!(:table_name => "some_other_table")

        migrate

        changed.reload.table_name.should == "custom_buttons"
        ignored.reload.table_name.should == "some_other_table"
      end
    end
  end

  migration_context :down do
    let(:miq_set_stub)        { migration_stub(:MiqSet) }
    let(:relationship_stub)   { migration_stub(:Relationship) }
    let(:pending_change_stub) { migration_stub(:RrPendingChange) }
    let(:sync_state_stub)     { migration_stub(:RrSyncState) }

    it "renames CustomButtonSet to AutomationUriSet in miq_sets" do
      changed = miq_set_stub.create!(:set_type => "CustomButtonSet", :guid => 'abc')
      ignored = miq_set_stub.create!(:set_type => "SomeOtherType",   :guid => 'def')

      migrate

      changed.reload.set_type.should == "AutomationUriSet"
      ignored.reload.set_type.should == "SomeOtherType"
    end

    it "renames CustomButtonSet to AutomationUriSet in relationships" do
      changed = relationship_stub.create!(:resource_type => "CustomButtonSet")
      ignored = relationship_stub.create!(:resource_type => "SomeOtherType")

      migrate

      changed.reload.resource_type.should == "AutomationUriSet"
      ignored.reload.resource_type.should == "SomeOtherType"
    end

    it "renames CustomButton to AutomationUri in relationships" do
      changed = relationship_stub.create!(:resource_type => "CustomButton")
      ignored = relationship_stub.create!(:resource_type => "SomeOtherType")

      migrate

      changed.reload.resource_type.should == "AutomationUri"
      ignored.reload.resource_type.should == "SomeOtherType"
    end

    context "renames custom_buttons to automation_uris" do
      before do
        pending_change_stub.create_table
        sync_state_stub.create_table
      end

      it "in rr#_pending_changes tables" do
        changed = pending_change_stub.create!(:change_table => "custom_buttons")
        ignored = pending_change_stub.create!(:change_table => "some_other_table")

        migrate

        changed.reload.change_table.should == "automation_uris"
        ignored.reload.change_table.should == "some_other_table"
      end

      it "in rr#_sync_states tables" do
        changed = sync_state_stub.create!(:table_name => "custom_buttons")
        ignored = sync_state_stub.create!(:table_name => "some_other_table")

        migrate

        changed.reload.table_name.should == "automation_uris"
        ignored.reload.table_name.should == "some_other_table"
      end
    end
  end
end
