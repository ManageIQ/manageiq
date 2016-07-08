require_migration

describe ChangeExcludeTableSettingsKey do
  let(:settings_change_stub) { migration_stub(:SettingsChange) }

  migration_context :up do
    it "changes the key for the exclude tables" do
      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :key           => "/workers/worker_base/replication_worker/replication/exclude_tables",
        :value         => %w(table1 table2 table3)
      )

      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :key           => "/workers/worker_base/replication_worker/replication/exclude_tables",
        :value         => %w(table1 table3)
      )

      migrate

      expect(settings_change_stub.where(:key => "/replication/exclude_tables").count).to eq 2
      expect(settings_change_stub.where(:key => "/workers/worker_base/replication_worker/replication/exclude_tables").count).to eq 0
    end
  end
end
