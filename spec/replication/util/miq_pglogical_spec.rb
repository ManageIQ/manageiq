describe MiqPglogical do
  let(:connection) { ApplicationRecord.connection }
  let(:pglogical)  { connection.pglogical }

  before do
    skip "pglogical must be installed" unless pglogical.installed?
    MiqServer.seed
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
        new_excludes = subject.configured_excludes << table

        c = MiqServer.my_server.get_config
        c.config.store_path(*described_class::SETTINGS_PATH, :exclude_tables, new_excludes)
        c.save

        subject.refresh_excludes
        expect(subject.included_tables).not_to include(table)
      end

      it "adds a newly included table" do
        table = subject.configured_excludes.last
        new_excludes = subject.configured_excludes - [table]

        c = MiqServer.my_server.get_config
        c.config.store_path(*described_class::SETTINGS_PATH, :exclude_tables, new_excludes)
        c.save

        subject.refresh_excludes
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
