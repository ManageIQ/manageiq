RSpec.describe ArPglogicalMigrationHelper do
  shared_context "without the schema_migrations_ran table" do
    before do
      allow(ActiveRecord::Base.connection).to receive(:table_exists?).and_call_original
      allow(ActiveRecord::Base.connection).to receive(:table_exists?).with("schema_migrations_ran").and_return(false)
    end
  end

  shared_context "with a dummy version" do
    let(:version) { "1234567890" }

    # sanity check - if this is somehow a version we have, these tests will make no sense
    before { expect(ActiveRecord::SchemaMigration.normalized_versions).not_to include(version) }
  end

  context "with a region seeded" do
    let!(:my_region) do
      MiqRegion.seed
      MiqRegion.my_region
    end

    describe ".update_local_migrations_ran" do
      context "without the schema_migrations_ran table" do
        include_context "without the schema_migrations_ran table"

        it "does nothing" do
          expect(ActiveRecord::SchemaMigration).not_to receive(:normalized_versions)
          described_class.update_local_migrations_ran("12345", :up)
        end
      end

      context "with the schema_migrations_ran table" do
        include_context "with a dummy version"

        it "adds the given version when the direction is :up" do
          described_class.update_local_migrations_ran(version, :up)
          expect(described_class.discover_schema_migrations_ran_class.where(:version => version).exists?).to eq(true)
        end

        it "doesn't blow up when there is no region" do
          MiqRegion.destroy_all
          MiqRegion.my_region_clear_cache
          described_class.update_local_migrations_ran(version, :up)
        end
      end
    end

    describe ArPglogicalMigrationHelper::RemoteRegionMigrationWatcher do
      include_context "with a dummy version"
      let(:helper_class) { Class.new(ActiveRecord::Base) { include ActiveRecord::IdRegions } }
      let(:other_region_number) { helper_class.my_region_number + rand(1..50) }
      let(:subscription) { double("Subscription", :enable => nil, :disable => nil, :provider_region => other_region_number) }

      subject do
        described_class.new(subscription, version).tap do |s|
          allow(s).to receive_messages(:puts => nil, :print => nil)
        end
      end

      describe "#wait_for_remote_region_migration" do
        def wait_for_migration_called
          @count ||= 0
          if @count == 5
            ArPglogicalMigrationHelper.discover_schema_migrations_ran_class.create!(:id => helper_class.id_in_region(1, other_region_number), :version => version)
          end
          @count += 1
        end

        context "without the schema_migrations_ran table present" do
          include_context "without the schema_migrations_ran table"

          it "does nothing" do
            expect(Vmdb.rails_logger).not_to receive(:info)
            subject.wait_for_remote_region_migration
          end
        end

        it "waits for the migration to be added" do
          allow(subject).to receive(:restart_subscription)
          expect(ArPglogicalMigrationHelper.discover_schema_migrations_ran_class.unscoped.where(:version => version).exists?).to eq(false)

          allow(subject).to receive(:wait_for_migration?).and_wrap_original do |m, _args|
            wait_for_migration_called
            m.call
          end

          subject.wait_for_remote_region_migration(0)

          expect(ArPglogicalMigrationHelper.discover_schema_migrations_ran_class.unscoped.where(:version => version).exists?).to eq(true)
        end
      end
    end
  end
end
