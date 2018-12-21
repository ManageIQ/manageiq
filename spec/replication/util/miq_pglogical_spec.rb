describe MiqPglogical do
  context "requires pglogical been installed" do
    let(:connection) { ApplicationRecord.connection }
    let(:pglogical)  { connection.pglogical }

    before do
      skip "pglogical must be installed" unless pglogical.installed?
      MiqServer.seed
    end

    describe "#active_excludes" do
      it "returns an empty array if a provider is not configured" do
        expect(subject.active_excludes).to eq([])
      end
    end

    describe "#provider?" do
      it "is false when a provider is not configured" do
        expect(subject.provider?).to be false
      end
    end

    describe "#node?" do
      it "is false when a provider is not configured" do
        expect(subject.node?).to be false
      end
    end

    describe "#configure_provider" do
      it "enables the extenstion and creates the replication set" do
        subject.configure_provider
        expect(pglogical.enabled?).to be true
        expect(pglogical.replication_sets).to include(described_class::REPLICATION_SET_NAME)
      end

      it "does not enable the extension when an exception is raised" do
        expect(subject).to receive(:create_replication_set).and_raise(PG::UniqueViolation)
        expect { subject.configure_provider }.to raise_error(PG::UniqueViolation)
        expect(pglogical.enabled?).to be false
      end
    end

    context "when configured as a provider" do
      before do
        subject.configure_provider
      end

      describe "#active_excludes" do
        it "returns the initial set of excluded tables" do
          expect(subject.active_excludes).to eq(connection.tables - subject.included_tables)
        end
      end

      describe "#provider?" do
        it "is true" do
          expect(subject.provider?).to be true
        end
      end

      describe "#node?" do
        it "is true" do
          expect(subject.node?).to be true
        end
      end

      describe "#destroy_provider" do
        it "removes the provider configuration" do
          subject.destroy_provider
          expect(subject.provider?).to be false
          expect(subject.node?).to be false
          expect(connection.extension_enabled?("pglogical")).to be false
        end
      end

      describe "#create_replication_set" do
        it "creates the correct initial set" do
          expected_excludes = subject.configured_excludes
          extra_excludes = subject.configured_excludes - connection.tables
          actual_excludes = connection.tables - subject.included_tables
          expect(actual_excludes | extra_excludes).to match_array(expected_excludes)
        end
      end

      describe ".refresh_excludes" do
        it "sets the configured excludes and calls refresh on an instance" do
          pgl = described_class.new
          expect(described_class).to receive(:new).and_return(pgl)
          expect(pgl).to receive(:refresh_excludes)

          new_excludes = %w(my new exclude tables)
          described_class.refresh_excludes(new_excludes)

          expect(pgl.configured_excludes).to match_array(new_excludes | described_class::ALWAYS_EXCLUDED_TABLES)
        end
      end

      describe "#refresh_excludes" do
        it "adds a new non excluded table" do
          connection.exec_query(<<-SQL)
            CREATE TABLE test (id INTEGER PRIMARY KEY)
          SQL
          subject.refresh_excludes
          expect(subject.included_tables).to include("test")
        end

        it "removes a newly excluded table" do
          table = subject.included_tables.first
          subject.configured_excludes += [table]

          expect(subject.active_excludes).not_to include(table)
          expect(subject.included_tables).to include(table)

          subject.refresh_excludes

          expect(subject.active_excludes).to include(table)
          expect(subject.included_tables).not_to include(table)
        end

        it "adds a newly included table" do
          current_excludes = subject.configured_excludes
          table = current_excludes.pop
          subject.configured_excludes = current_excludes

          expect(subject.active_excludes).to include(table)
          expect(subject.included_tables).not_to include(table)

          subject.refresh_excludes

          expect(subject.active_excludes).not_to include(table)
          expect(subject.included_tables).to include(table)
        end
      end
    end

    describe ".region_to_node_name" do
      it "returns the correct name" do
        expect(described_class.region_to_node_name(4)).to eq("region_4")
      end
    end

    describe ".node_name_to_region" do
      it "returns the correct region" do
        expect(described_class.node_name_to_region("region_5")).to eq(5)
      end
    end
  end

  describe ".save_remote_region" do
    it "sets replication type for this region to 'remote'" do
      allow(described_class).to receive(:refresh_excludes)
      expect(MiqRegion).to receive(:replication_type=).with(:remote)
      described_class.save_remote_region("")
    end

    it "updates list of tables to be excluded from replication" do
      tables = "---\n- vmdb_databases\n- vmdb_indexes\n- vmdb_metrics\n- vmdb_tables\n"
      allow(MiqRegion).to receive(:replication_type=)
      expect(described_class).to receive(:refresh_excludes).with(YAML.safe_load(tables))
      described_class.save_remote_region(tables)
    end

    it "does not updates list of tables to be excluded from replication if passed parameter is empty" do
      allow(MiqRegion).to receive(:replication_type=)
      expect(described_class).not_to receive(:refresh_excludes)
      described_class.save_remote_region("")
    end
  end

  describe ".save_global_region" do
    let(:subscription) { double }
    it "sets replication type for this region to 'global'" do
      allow(described_class).to receive(:refresh_excludes)
      expect(MiqRegion).to receive(:replication_type=).with(:global)
      described_class.save_global_region([], [])
    end

    it "deletes subscriptions passed as second paramer" do
      allow(MiqRegion).to receive(:replication_type=)
      expect(subscription).to receive(:delete)
      described_class.save_global_region([], [subscription])
    end

    it "saves subscriptions passed as first paramer" do
      allow(MiqRegion).to receive(:replication_type=)
      expect(subscription).to receive(:save!)
      described_class.save_global_region([subscription], [])
    end
  end
end
