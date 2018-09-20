describe ArPglogicalMigration::ArPglogicalMigrationHelper do
  let!(:my_region) do
    MiqRegion.seed
    MiqRegion.my_region
  end

  before { allow(described_class).to receive_messages(:puts => nil, :print => nil) }

  context "without the migrations ran column" do
    before do
      column_list = %w(id region created_at updated_at description guid).map { |n| double(:name => n) }
      allow(ActiveRecord::Base.connection).to receive(:columns).with("miq_regions").and_return(column_list)
    end

    describe ".migrations_column_present?" do
      it "is falsey" do
        expect(described_class.migrations_column_present?).to be_falsey
      end
    end

    describe ".wait_for_remote_region_migrations" do
      it "does nothing" do
        expect(MiqRegion).not_to receive(:find)
        described_class.wait_for_remote_region_migration(double("subscription"), "12345")
      end
    end

    describe ".update_local_migrations_ran" do
      it "does nothing" do
        expect(MiqRegion).not_to receive(:my_region)
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

  context "with a dummy version" do
    let(:version) { "1234567890" }

    # sanity check - if this is somehow a version we have, these tests will make no sense
    before { expect(my_region.migrations_ran).not_to include(version) }

    describe ".wait_for_remote_region_migration" do
      let(:subscription) { double("Subscription", :enable => nil, :disable => nil, :provider_region => my_region.region) }

      it "sleeps until the migration is added" do
        allow(described_class).to receive(:restart_subscription)
        my_region.update_attributes!(:migrations_ran => nil)
        t = Thread.new do
          Thread.current.abort_on_exception = true
          # need to stub these because the thread uses a separate connection object which won't be in the same transaction
          allow(MiqRegion).to receive(:find_by).with(:region => my_region.region).and_return(my_region)
          allow(my_region).to receive(:reload)
          described_class.wait_for_remote_region_migration(subscription, version, 0)
        end

        # Try to pass execution to the created thread
        # NOTE: This is could definitely be a source of weird spec timing issues because
        #       we're relying on the thread scheduler to pass to the next thread
        #       when we sleep, but if this isn't here we likely won't execute the conditional
        #       block in .wait_for_remote_region_migrations
        sleep 1

        expect(t.alive?).to be true
        my_region.update_attributes!(:migrations_ran => ActiveRecord::SchemaMigration.normalized_versions << version)

        # Wait a max of 5 seconds so we don't disrupt the whole test suite if something terrible happens
        t = t.join(5)
        expect(t.status).to be false
      end
    end

    describe ".update_local_migrations_ran" do
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
end
