require_migration

describe AddNotificationTablesToReplicationExcludes do
  let(:settings_change_stub) { migration_stub(:SettingsChange) }
  let(:server_one)           { FactoryGirl.create(:miq_server) }
  let(:server_two)           { FactoryGirl.create(:miq_server) }

  migration_context :up do
    it "adds notification tables to the replication excludes" do
      server_one.settings_changes
                .create!(:key   => described_class::EXCLUDES_KEY,
                         :value => %w(schema_migrations))
      server_two.settings_changes
                .create!(:key   => described_class::EXCLUDES_KEY,
                         :value => %w(ar_internal_metadata))

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
      server_one.settings_changes
                .create!(:key   => described_class::EXCLUDES_KEY,
                         :value => %w(notification_types notifications schema_migrations))
      server_two.settings_changes
                .create!(:key   => described_class::EXCLUDES_KEY,
                         :value => %w(notification_types notification_recipients ar_internal_metadata))

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
