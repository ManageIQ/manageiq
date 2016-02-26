require 'miq_pglogical'

describe MiqPglogicalProvider do
  let(:connection) { ActiveRecord::Base.connection }
  let(:pglogical)  { connection.pglogical }
  subject          { described_class.new(connection) }

  before do
    skip "pglogical must be installed" unless pglogical.installed?
    MiqServer.seed
    subject.configure_provider
  end

  describe "#provider?" do
    it "is true when a provider is configured" do
      expect(subject.provider?).to be true
    end
  end

  describe "#destroy_provider" do
    it "removes the provider configuration" do
      subject.destroy_provider
      expect(pglogical.nodes.num_tuples).to eq(0)
      expect(pglogical.replication_sets).not_to include(described_class::REPLICATION_SET_NAME)
      expect(subject.provider?).to be false
    end
  end

  describe "#create_replication_set" do
    it "creates the correct initial set" do
      expected_excludes = subject.configured_excludes
      actual_excludes = connection.tables - subject.included_tables
      expect(actual_excludes).to match_array(expected_excludes)
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
      c.config.store_path(:replication, :exclude_tables, new_excludes)
      c.save

      subject.refresh_excludes
      expect(subject.included_tables).not_to include(table)
    end

    it "adds a newly included table" do
      table = subject.configured_excludes.first
      new_excludes = subject.configured_excludes - [table]

      c = MiqServer.my_server.get_config
      c.config.store_path(:replication, :exclude_tables, new_excludes)
      c.save

      subject.refresh_excludes
      expect(subject.included_tables).to include(table)
    end
  end
end
