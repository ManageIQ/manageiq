require_migration

describe RemoveReplicationWorkerSettings do
  let(:settings_change_stub) { migration_stub(:SettingsChange) }

  migration_context :up do
    it "removes the replication worker settings" do
      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :key           => "/workers/worker_base/replication_worker/memory_threshold",
        :value         => "5.gigabytes"
      )

      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :key           => "/workers/worker_base/replication_worker/replication/destination/host",
        :value         => "somehost.example.com"
      )

      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :key           => "/workers/worker_base/replication_worker/replication/destination/user",
        :value         => "root"
      )

      migrate

      expect(settings_change_stub.where("key LIKE ?", "/workers/worker_base/replication_worker%").count).to eq 0
    end
  end
end
