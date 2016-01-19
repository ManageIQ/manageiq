require_migration

describe RemoveVmDiscoverRowFromMiqEventDefinitions do
  let(:miq_event_def_stub) { migration_stub(:MiqEventDefinition) }
  let(:relationship_stub)  { migration_stub(:Relationship) }

  migration_context :up do
    it "removes vm_discover from table miq_event_definitions and its relationships from table relationships" do
      deleted = miq_event_def_stub.create!(:name => "vm_discover")
      ignored = miq_event_def_stub.create!(:name => "vm_start")

      deleted_rel = relationship_stub.create!(:resource_type => 'MiqEventDefinition', :resource_id => deleted.id)
      ignored_rel = relationship_stub.create!(:resource_type => 'AnyOtherType', :resource_id => deleted.id)

      migrate

      expect { deleted.reload }.to     raise_error(ActiveRecord::RecordNotFound)
      expect { ignored.reload }.to_not raise_error

      expect { deleted_rel.reload }.to     raise_error(ActiveRecord::RecordNotFound)
      expect { ignored_rel.reload }.to_not raise_error
    end
  end
end
