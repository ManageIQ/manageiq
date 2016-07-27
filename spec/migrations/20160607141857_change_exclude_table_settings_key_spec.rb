require_migration

describe ChangeExcludeTableSettingsKey do
  let(:settings_change_stub) { migration_stub(:SettingsChange) }

  migration_context :up do
    it "changes the key for the exclude tables" do
      insert_test_records(described_class::OLD_KEY)

      migrate

      expect(settings_change_stub.where(:key => described_class::NEW_KEY).count).to eq 2
      expect(settings_change_stub.where(:key => described_class::OLD_KEY).count).to eq 0
    end
  end

  migration_context :down do
    it "changes the key for the exclude tables" do
      insert_test_records(described_class::NEW_KEY)

      migrate

      expect(settings_change_stub.where(:key => described_class::OLD_KEY).count).to eq 2
      expect(settings_change_stub.where(:key => described_class::NEW_KEY).count).to eq 0
    end
  end

  def insert_test_records(key)
    settings_change_stub.create!(
      :resource_type => "MiqServer",
      :key           => key,
      :value         => %w(table1 table2 table3)
    )

    settings_change_stub.create!(
      :resource_type => "MiqServer",
      :key           => key,
      :value         => %w(table1 table3)
    )
  end
end
