require_migration

describe FixReplicationOnUpgradeFromVersionFour do
  let(:configuration_stub)  { migration_stub(:Configuration) }

  migration_context :up do
    it "updates the configuration to have the new replication settings" do
      old_settings = {
        "workers" => {
          "worker_base" => {
            :replication_worker => {
              :replication => {
                :include_tables => ["."],
                :exclude_tables => [
                  "doesn't",
                  "really",
                  "matter"
                ]
              }
            }
          }
        }
      }
      configuration_stub.create!(:typ => 'vmdb', :settings => old_settings)

      migrate

      settings = configuration_stub.first.settings
      expect(settings.key_path?("workers", "worker_base", :replication_worker, :replication, :include_tables))
        .to be_falsey
      expect(settings.fetch_path("workers", "worker_base", :replication_worker, :replication, :exclude_tables))
        .to eq(described_class::V5_DEFAULT_EXCLUDE_TABLES)
    end
  end
end
