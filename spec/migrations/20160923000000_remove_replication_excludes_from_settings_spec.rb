require_migration

describe RemoveReplicationExcludesFromSettings do
  let(:settings_change_stub) { migration_stub(:SettingsChange) }

  migration_context :up do
    it "removes the replication excludes key rows" do
      settings_change_stub.create!(
        :key   => described_class::EXCLUDES_KEY,
        :value => %w(schema_migrations)
      )
      settings_change_stub.create!(
        :key   => described_class::EXCLUDES_KEY,
        :value => %w(ar_internal_metadata)
      )
      settings_change_stub.create!(
        :key   => "/some/other/key",
        :value => %w(ar_internal_metadata)
      )

      migrate

      expect(settings_change_stub.where(:key => described_class::EXCLUDES_KEY)).to be_empty
      expect(settings_change_stub.where(:key => "/some/other/key")).to_not be_empty
    end
  end
end
