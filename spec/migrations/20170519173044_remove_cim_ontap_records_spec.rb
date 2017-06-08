require_migration

describe RemoveCimOntapRecords do
  let(:server_role_stub)         { migration_stub(:ServerRole) }
  let(:assigned_role_stub)       { migration_stub(:AssignedServerRole) }
  let(:settings_change_stub)     { migration_stub(:SettingsChange) }
  let(:miq_worker_stub)          { migration_stub(:MiqWorker) }
  let(:miq_product_feature_stub) { migration_stub(:MiqProductFeature) }
  let(:miq_roles_feature_stub)   { migration_stub(:MiqRolesFeature) }

  migration_context :up do
    it "removes the server roles" do
      all_roles = described_class::ROLES + ["other"]

      all_roles.each do |role_name|
        role = server_role_stub.create!(:name => role_name)
        assigned_role_stub.create!(:server_role_id => role.id)
      end

      migrate

      expect(server_role_stub.count).to eq 1
      expect(server_role_stub.first.name).to eq "other"

      expect(assigned_role_stub.count).to eq 1
      expect(assigned_role_stub.first.server_role_id).to eq server_role_stub.first.id
    end

    it "removes the roles from currently configured servers" do
      all_roles = %w(a b c d e).zip(described_class::ROLES).flatten.join(",")

      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :key           => "/server/role",
        :value         => all_roles
      )

      migrate

      expect(settings_change_stub.first.value).to eq "a,b,c,d,e"
    end

    it "removes workers" do
      all_workers = (described_class::WORKERS + ["OtherWorker"])

      all_workers.each { |w| miq_worker_stub.create!(:type => w) }

      migrate

      expect(miq_worker_stub.count).to eq 1
      expect(miq_worker_stub.first.type).to eq "OtherWorker"
    end

    it "removes settings" do
      {
        "/storage/alignment/boundary"                                                              => "4.kilobytes", # Should not be removed
        "/storage/inventory/full_refresh_schedule"                                                 => "38 * * * *",
        "/storage/metrics_collection/collection_schedule"                                          => "0,15,30,45  * * * *",
        "/storage/metrics_collection/hourly_rollup_schedule"                                       => "8 * * * *",
        "/storage/metrics_history/purge_schedule"                                                  => "50 * * * *",
        "/storage/metrics_history/keep_daily_metrics"                                              => "6.months",
        "/workers/worker_base/smis_refresh_worker/memory_threshold"                                => "2.gigabytes",
        "/workers/worker_base/queue_worker_base/netapp_refresh_worker/memory_threshold"            => "2.gigabytes",
        "/workers/worker_base/queue_worker_base/storage_metrics_collector_worker/memory_threshold" => "2.gigabytes",
        "/workers/worker_base/queue_worker_base/vmdb_storage_bridge_worker/memory_threshold"       => "2.gigabytes",
      }.each { |k, v| settings_change_stub.create!(:key => k, :value => v) }

      migrate

      expect(settings_change_stub.count).to eq 1
      expect(settings_change_stub.first.key).to eq "/storage/alignment/boundary"
      expect(settings_change_stub.first.value).to eq "4.kilobytes"
    end

    it "remove product features" do
      all_features = (described_class::PRODUCT_FEATURES[0, 5] + ["other"])

      ids = all_features.collect do |f|
        pf = miq_product_feature_stub.create!(:identifier => f)
        miq_roles_feature_stub.create!(:miq_product_feature_id => pf.id)
        pf.id
      end
      other_id = ids.last

      migrate

      expect(miq_product_feature_stub.count).to eq 1
      expect(miq_product_feature_stub.first.identifier).to eq "other"
      expect(miq_roles_feature_stub.count).to eq 1
      expect(miq_roles_feature_stub.first.miq_product_feature_id).to eq other_id
    end
  end
end
