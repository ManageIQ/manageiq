require_migration

describe AddNotificationTablesToReplicationExcludes do
  let(:settings_change_stub) { migration_stub(:SettingsChange) }

  def next_miq_server_id
    @miq_server_id ||= anonymous_class_with_id_regions.rails_sequence_start
    @miq_server_id += 1
  end

  migration_context :up do
    it "adds notification tables to the replication excludes" do
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
      changes.each do |c|
        expect(c.value).to include("notifications")
        expect(c.value).to include("notification_types")
        expect(c.value).to include("notification_recipients")
      end
    end
  end

  migration_context :down do
    it "removes notification tables from the replication excludes" do
      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :resource_id   => next_miq_server_id,
        :key           => described_class::EXCLUDES_KEY,
        :value         => %w(notification_types notifications schema_migrations)
      )
      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :resource_id   => next_miq_server_id,
        :key           => described_class::EXCLUDES_KEY,
        :value         => %w(notification_types notification_recipients ar_internal_metadata)
      )

      migrate

      changes = settings_change_stub.where(:key => described_class::EXCLUDES_KEY)
      changes.each do |c|
        expect(c.value).not_to include("notifications")
        expect(c.value).not_to include("notification_types")
        expect(c.value).not_to include("notification_recipients")
      end
    end
  end
end
