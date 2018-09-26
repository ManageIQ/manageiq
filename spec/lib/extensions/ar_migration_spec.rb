shared_context "without the migrations ran column" do
  before do
    column_list = %w(id region created_at updated_at description guid).map { |n| double(:name => n) }
    allow(ActiveRecord::Base.connection).to receive(:columns).with("miq_regions").and_return(column_list)
  end
end

shared_context "with a dummy version" do
  let(:version) { "1234567890" }

  # sanity check - if this is somehow a version we have, these tests will make no sense
  before { expect(my_region.migrations_ran).not_to include(version) }
end

context "with a region seeded" do
  let!(:my_region) do
    MiqRegion.seed
    MiqRegion.my_region
  end

  describe ArPglogicalMigration::PglogicalMigrationHelper do
    context "without the migrations ran column" do
      include_context "without the migrations ran column"

      describe ".migrations_column_present?" do
        it "is falsey" do
          expect(described_class.migrations_column_present?).to be_falsey
        end
      end

      describe ".update_local_migrations_ran" do
        it "does nothing" do
          expect(ActiveRecord::SchemaMigration).not_to receive(:normalized_versions)
          described_class.update_local_migrations_ran("12345", :up)
        end
      end
    end

    describe ".migrations_column_present?" do
      it "is truthy" do
        # we never want to remove this column so we can just test directly
        expect(described_class.migrations_column_present?).to be_truthy
      end
    end

    describe ".update_local_migrations_ran" do
      include_context "with a dummy version"

      it "adds the given version when the direction is :up" do
        described_class.update_local_migrations_ran(version, :up)
        expect(my_region.reload.migrations_ran).to match_array(ActiveRecord::SchemaMigration.normalized_versions << version)
      end

      it "doesn't blow up when there is no region" do
        MiqRegion.destroy_all
        MiqRegion.my_region_clear_cache
        described_class.update_local_migrations_ran(version, :up)
      end
    end
  end

  describe ArPglogicalMigration::RemoteRegionMigrationWatcher do
    include_context "with a dummy version"

    let(:subscription) { double("Subscription", :enable => nil, :disable => nil, :provider_region => my_region.region) }

    subject do
      described_class.new(subscription, version).tap do |s|
        allow(s).to receive_messages(:puts => nil, :print => nil)
      end
    end

    describe "#wait_for_remote_region_migrations" do
      context "without the migrations ran column present" do
        include_context "without the migrations ran column"

        it "does nothing" do
          expect(Vmdb.rails_logger).not_to receive(:info)
          subject.wait_for_remote_region_migration
        end
      end

      it "sleeps until the migration is added" do
        allow(subject).to receive(:restart_subscription)
        allow(subject.region).to receive(:reload)

        subject.region.update_attributes!(:migrations_ran => nil)

        t = Thread.new do
          Thread.current.abort_on_exception = true
          subject.wait_for_remote_region_migration(0)
        end

        # Try to pass execution to the created thread
        # NOTE: This is could definitely be a source of weird spec timing issues because
        #       we're relying on the thread scheduler to pass to the next thread
        #       when we sleep, but if this isn't here we likely won't execute the conditional
        #       block in .wait_for_remote_region_migrations
        sleep 1

        expect(t.alive?).to be true
        subject.region.update_attributes!(:migrations_ran => ActiveRecord::SchemaMigration.normalized_versions << version)

        # Wait a max of 5 seconds so we don't disrupt the whole test suite if something terrible happens
        t = t.join(5)
        expect(t.status).to be false
      end
    end
  end
end
