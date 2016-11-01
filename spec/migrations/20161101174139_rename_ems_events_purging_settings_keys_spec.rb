require_migration

describe RenameEmsEventsPurgingSettingsKeys do
  let(:settings_change_stub) { migration_stub(:SettingsChange) }

  migration_context :up do
    it "changes the keys for event_streams purging" do
      insert_test_records(described_class::OLD_KEYS)

      migrate

      expect(settings_change_stub.where(:key => described_class::NEW_KEYS).count).to eq(2)
      expect(settings_change_stub.where(:key => described_class::OLD_KEYS).count).to eq(0)
    end
  end

  migration_context :down do
    it "changes the keys for ems_events purging" do
      insert_test_records(described_class::NEW_KEYS)

      migrate

      expect(settings_change_stub.where(:key => described_class::NEW_KEYS).count).to eq(0)
      expect(settings_change_stub.where(:key => described_class::OLD_KEYS).count).to eq(2)
    end
  end

  def insert_test_records(keys)
    keys.each do |key|
      settings_change_stub.create!(:resource_type => "MiqServer", :key => key, :value => "10.days")
    end
  end
end
