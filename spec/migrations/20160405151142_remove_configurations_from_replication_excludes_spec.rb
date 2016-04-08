require_migration

describe RemoveConfigurationsFromReplicationExcludes do
  let(:settings_change_stub) { migration_stub(:SettingsChange) }
  let(:server_one)           { FactoryGirl.create(:miq_server) }
  let(:server_two)           { FactoryGirl.create(:miq_server) }

  migration_context :up do
    it "removes configurations from the replication excludes" do
      server_one.settings_changes
                .create!(:key   => described_class::EXCLUDES_KEY,
                         :value => %w(configurations schema_migrations))
      server_two.settings_changes
                .create!(:key   => described_class::EXCLUDES_KEY,
                         :value => %w(configurations ar_internal_metadata))

      migrate

      changes = settings_change_stub.where(:key => described_class::EXCLUDES_KEY)
      changes.each { |c| expect(c.value).not_to include("configurations") }
    end
  end

  migration_context :down do
    it "adds configurations to the replication excludes" do
      server_one.settings_changes
                .create!(:key   => described_class::EXCLUDES_KEY,
                         :value => %w(schema_migrations))
      server_two.settings_changes
                .create!(:key   => described_class::EXCLUDES_KEY,
                         :value => %w(ar_internal_metadata))

      migrate

      changes = settings_change_stub.where(:key => described_class::EXCLUDES_KEY)
      changes.each { |c| expect(c.value).to include("configurations") }
    end
  end
end
