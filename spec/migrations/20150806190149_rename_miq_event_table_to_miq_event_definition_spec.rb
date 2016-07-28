require_migration

describe RenameMiqEventTableToMiqEventDefinition do
  migration_context :up do
    let(:miq_set_stub)          { migration_stub(:MiqSet) }
    let(:relationship_stub)     { migration_stub(:Relationship) }

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
  end

  migration_context :down do
    let(:miq_set_stub)          { migration_stub(:MiqSet) }
    let(:relationship_stub)     { migration_stub(:Relationship) }

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
  end
end
