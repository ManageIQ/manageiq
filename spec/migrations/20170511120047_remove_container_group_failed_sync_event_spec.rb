require_migration

describe RemoveContainerGroupFailedSyncEvent do
  let(:miq_event_def_stub) { migration_stub(:MiqEventDefinition) }
  let(:relationship_stub)  { migration_stub(:Relationship) }

  migration_context :up do
    it "removes containergroup_failedsync from table miq_event_definitions and its relationships" do
      deleted = miq_event_def_stub.create!(:name => "containergroup_failedsync")
      ignored = miq_event_def_stub.create!(:name => "containergroup_outofdisk")

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
