RSpec.describe MiqPglogical do
  let(:ar_connection) { ApplicationRecord.connection }
  let(:pglogical)     { PG::LogicalReplication::Client.new(ar_connection.raw_connection) }

  before do
    EvmSpecHelper.local_miq_server
  end

  describe "#subscriber?" do
    it "is false when a subscription is not configured" do
      expect(subject.subscriber?).to be false
    end
  end

  describe "#provider?" do
    it "is false when a provider is not configured" do
      expect(subject.provider?).to be false
    end
  end

  describe "#configure_provider" do
    it "creates the publication" do
      subject.configure_provider
      expect(pglogical.publications.first["name"]).to eq(described_class::PUBLICATION_NAME)
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

    describe "#destroy_provider" do
      it "removes the provider configuration" do
        subject.destroy_provider
        expect(subject.provider?).to be false
      end
    end

    describe "#create_replication_set" do
      it "creates the correct initial set" do
        expected_excludes = subject.excludes
        actual_excludes = ar_connection.tables - subject.included_tables
        expect(actual_excludes | MiqPglogical::ALWAYS_EXCLUDED_TABLES).to match_array(expected_excludes)
      end
    end

    describe "#refresh_excludes" do
      it "adds a new non excluded table" do
        ar_connection.exec_query(<<-SQL)
          CREATE TABLE test (id INTEGER PRIMARY KEY)
        SQL
        subject.refresh_excludes
        expect(subject.included_tables).to include("test")
      end
    end
  end

  describe ".save_global_region" do
    let(:subscription) { double }
    it "sets replication type for this region to 'global'" do
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
