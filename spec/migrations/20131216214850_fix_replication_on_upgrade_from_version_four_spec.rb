require_migration

describe FixReplicationOnUpgradeFromVersionFour do
  let(:configuration_stub)  { migration_stub(:Configuration) }
  let(:pending_change_stub) { migration_stub(:RrPendingChange) }
  let(:sync_state_stub)     { migration_stub(:RrSyncState) }

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

    context "handles replication" do
      before do
        pending_change_stub.create_table
        sync_state_stub.create_table
      end

      def expect_replication_shell_calls
        # HACK: Just verify that the callouts are made...we can't actually run
        # them unless we have replication set up, which is not yet possible in a
        # migration spec.
        require 'awesome_spawn'
        expect(AwesomeSpawn)
          .to receive(:run!).with("bin/rake evm:db:environmentlegacykey evm:dbsync:prepare_replication_without_sync")
        expect(AwesomeSpawn)
          .to receive(:run!).with("bin/rake evm:db:environmentlegacykey evm:dbsync:uninstall" \
                                  " drift_states miq_cim_derived_metrics miq_request_tasks" \
                                  " miq_storage_metrics storages_vms_and_templates")
      end

      it "for renamed tables in rr_pending_changes" do
        changed = [
          pending_change_stub.create!(:change_table => "states"),
          pending_change_stub.create!(:change_table => "miq_cim_derived_stats"),
          pending_change_stub.create!(:change_table => "miq_provisions"),
          pending_change_stub.create!(:change_table => "miq_cim_stats"),
          pending_change_stub.create!(:change_table => "storages_vms")
        ]
        ignored = pending_change_stub.create!(:change_table => "accounts")

        expect_replication_shell_calls

        migrate

        expect(changed.collect { |c| c.reload.change_table }).to eq(%w(
          drift_states
          miq_cim_derived_metrics
          miq_request_tasks
          miq_storage_metrics
          storages_vms_and_templates
        ))
        expect(ignored.reload.change_table).to eq("accounts")
      end

      it "for renamed tables in rr_sync_states" do
        changed = [
          sync_state_stub.create!(:table_name => "states"),
          sync_state_stub.create!(:table_name => "miq_cim_derived_stats"),
          sync_state_stub.create!(:table_name => "miq_provisions"),
          sync_state_stub.create!(:table_name => "miq_cim_stats"),
          sync_state_stub.create!(:table_name => "storages_vms")
        ]
        ignored = sync_state_stub.create!(:table_name => "accounts")

        expect_replication_shell_calls

        migrate

        expect(changed.collect { |c| c.reload.table_name }).to eq(%w(
          drift_states
          miq_cim_derived_metrics
          miq_request_tasks
          miq_storage_metrics
          storages_vms_and_templates
        ))
        expect(ignored.reload.table_name).to eq("accounts")
      end

      it "for removed tables in rr_sync_states" do
        deleted = [
          sync_state_stub.create!(:table_name => "automation_requests"),
          sync_state_stub.create!(:table_name => "automation_tasks"),
          sync_state_stub.create!(:table_name => "miq_provision_requests"),
          sync_state_stub.create!(:table_name => "vim_performances")
        ]
        ignored = sync_state_stub.create!(:table_name => "accounts")

        expect_replication_shell_calls

        migrate

        deleted.each { |c| expect { c.reload }.to raise_error(ActiveRecord::RecordNotFound) }
        expect(ignored.reload.table_name).to eq("accounts")
      end
    end
  end
end
