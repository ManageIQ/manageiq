require_migration

describe RemoveMiqServerProductUpdateJoinTable do
  let(:settings_change_stub) { migration_stub(:SettingsChange) }
  let(:my_server)            { FactoryGirl.create(:miq_server) }
  let(:other_server)         { FactoryGirl.create(:miq_server) }

  migration_context :up do
    it "removes miq_servers_product_updates from replication excludes" do
      my_server.settings_changes
               .create!(:key   => described_class::EXCLUDES_KEY,
                        :value => %w(miq_servers_product_updates schema_migrations))

      other_server.settings_changes
                  .create!(:key   => described_class::EXCLUDES_KEY,
                           :value => %w(miq_servers_product_updates ar_internal_metadata))

      migrate

      changes = settings_change_stub.where(:key => described_class::EXCLUDES_KEY)
      changes.each do |c|
        expect(c.value).not_to include("miq_servers_product_updates")
      end
    end
  end

  migration_context :down do
    it "adds miq_servers_product_updates to replication excludes" do
      my_server.settings_changes
               .create!(:key   => described_class::EXCLUDES_KEY,
                        :value => ["schema_migrations"])

      other_server.settings_changes
                  .create!(:key   => described_class::EXCLUDES_KEY,
                           :value => ["ar_internal_metadata"])

      migrate

      changes = settings_change_stub.where(:key => described_class::EXCLUDES_KEY)
      changes.each do |c|
        expect(c.value).to include("miq_servers_product_updates")
      end
    end
  end
end
