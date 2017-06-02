require_migration

describe RemoveConfigurationsFromReplicationExcludes do
  let(:settings_change_stub) { migration_stub(:SettingsChange) }

  def next_miq_server_id
    @miq_server_id ||= anonymous_class_with_id_regions.rails_sequence_start
    @miq_server_id += 1
  end

  migration_context :up do
    it "removes configurations from the replication excludes" do
      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :resource_id   => next_miq_server_id,
        :key           => described_class::EXCLUDES_KEY,
        :value         => %w(configurations schema_migrations)
      )
      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :resource_id   => next_miq_server_id,
        :key           => described_class::EXCLUDES_KEY,
        :value         => %w(configurations ar_internal_metadata)
      )

      migrate

      changes = settings_change_stub.where(:key => described_class::EXCLUDES_KEY)
      changes.each { |c| expect(c.value).not_to include("configurations") }
    end
  end

  migration_context :down do
    it "adds configurations to the replication excludes" do
      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :resource_id   => next_miq_server_id,
        :key           => described_class::EXCLUDES_KEY,
        :value         => %w(schema_migrations)
      )
      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :resource_id   => next_miq_server_id,
        :key           => described_class::EXCLUDES_KEY,
        :value         => %w(ar_internal_metadata)
      )

      migrate

      changes = settings_change_stub.where(:key => described_class::EXCLUDES_KEY)
      changes.each { |c| expect(c.value).to include("configurations") }
    end
  end
end
