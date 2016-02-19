require 'miq_pglogical'

describe MiqPglogical do
  let(:connection) { ActiveRecord::Base.connection }
  let(:pglogical)  { connection.pglogical }

  before do
    skip "pglogical must be installed" unless pglogical.installed?
    MiqServer.seed
    pglogical.enable
    described_class.create_local_node
    described_class.create_replication_set
  end

  describe ".create_replication_set" do
    it "creates the correct initial set" do
      expected_excludes = described_class.configured_excludes
      actual_excludes = connection.tables - described_class.included_tables
      expect(actual_excludes).to match_array(expected_excludes)
    end
  end

  describe ".refresh_excludes" do
    it "adds a new non excluded table" do
      connection.exec_query(<<-SQL)
        CREATE TABLE test (id INTEGER PRIMARY KEY)
      SQL
      described_class.refresh_excludes
      expect(described_class.included_tables).to include("test")
    end

    it "removes a newly excluded table" do
      table = described_class.included_tables.first
      new_excludes = described_class.configured_excludes << table

      c = MiqServer.my_server.get_config
      c.config.store_path(:workers, :worker_base, :replication_worker, :replication, :exclude_tables, new_excludes)
      c.save

      described_class.refresh_excludes
      expect(described_class.included_tables).not_to include(table)
    end

    it "adds a newly included table" do
      table = described_class.configured_excludes.first
      new_excludes = described_class.configured_excludes - [table]

      c = MiqServer.my_server.get_config
      c.config.store_path(:workers, :worker_base, :replication_worker, :replication, :exclude_tables, new_excludes)
      c.save

      described_class.refresh_excludes
      expect(described_class.included_tables).to include(table)
    end
  end
end
