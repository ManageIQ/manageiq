require_migration

describe RemoveMiqServerProductUpdateJoinTable do
  let(:settings_change_stub) { migration_stub(:SettingsChange) }

  def next_miq_server_id
    @miq_server_id ||= anonymous_class_with_id_regions.rails_sequence_start
    @miq_server_id += 1
  end

  migration_context :up do
    it "removes miq_servers_product_updates from replication excludes" do
      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :resource_id   => next_miq_server_id,
        :key           => described_class::EXCLUDES_KEY,
        :value         => %w(miq_servers_product_updates schema_migrations)
      )
      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :resource_id   => next_miq_server_id,
        :key           => described_class::EXCLUDES_KEY,
        :value         => %w(miq_servers_product_updates ar_internal_metadata)
      )

      migrate

      changes = settings_change_stub.where(:key => described_class::EXCLUDES_KEY)
      changes.each do |c|
        expect(c.value).not_to include("miq_servers_product_updates")
      end
    end
  end

  migration_context :down do
    it "adds miq_servers_product_updates to replication excludes" do
      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :resource_id   => next_miq_server_id,
        :key           => described_class::EXCLUDES_KEY,
        :value         => ["schema_migrations"]
      )
      settings_change_stub.create!(
        :resource_type => "MiqServer",
        :resource_id   => next_miq_server_id,
        :key           => described_class::EXCLUDES_KEY,
        :value         => ["ar_internal_metadata"]
      )

      migrate

      changes = settings_change_stub.where(:key => described_class::EXCLUDES_KEY)
      changes.each do |c|
        expect(c.value).to include("miq_servers_product_updates")
      end
    end
  end
end
