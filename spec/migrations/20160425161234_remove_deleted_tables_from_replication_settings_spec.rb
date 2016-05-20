require_migration

describe RemoveDeletedTablesFromReplicationSettings do
  let(:settings_change_stub) { migration_stub(:SettingsChange) }

  migration_context :up do
    it "removes deleted tables from an existing settings change" do
      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :key           => "/workers/worker_base/replication_worker/replication/exclude_tables",
        :value         => %w(table1 vim_performances table2 miq_events table3 miq_license_contents table4)
      )

      migrate

      expect(settings_change_stub.count).to eq(1)

      change = settings_change_stub.where("key LIKE '%/exclude_tables'").last
      expect(change.value).to eq %w(table1 table2 table3 table4)
    end
  end
end
