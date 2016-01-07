require File.expand_path(File.join(File.dirname(__FILE__), 'replication_helper'))

describe "evm:dbsync" do
  before(:each) do
    MiqRegion.seed
    Zone.seed
    MiqServer.seed

    master_db_config = VMDB::Config.new("database").config[:test].merge(:database => "#{ActiveRecord::Base.connection.current_database}_master")

    c = MiqServer.my_server.get_config
    c.config.store_path(:workers, :worker_base, :replication_worker, :replication, :destination, master_db_config)
    c.save

    @replication_config = c.config.fetch_path(:workers, :worker_base, :replication_worker, :replication)
    @rr_prefix = "rr#{MiqRegion.my_region_number}"

    class ::MasterDb < ActiveRecord::Base; end
    MasterDb.establish_connection(master_db_config)
    @master_connection = MasterDb.connection

    @slave_connection = ActiveRecord::Base.connection
  end

  after(:each) do
    Object.send(:remove_const, :MasterDb)
  end

  it ":prepare_replication" do
    insert_initial_records
    run_initial_sync

    assert_replication_enabled
    assert_initial_replicated_records

    # TODO:
    # insert a row into every table to test inserts
    # delete one of the 2 initial rows to test deletes
    # update one of the 2 initial rows to tests updates

    # rake evm:dbsync:replicate
    # since the process doesn't actually end, monitor the rr0_pending_changes and
    #   wait until it's empty.  Once table is empty, or timeout is reached send SIGINT
    #   to the process

    # verify content of rr0* tables
    # verify that master database does or does not contains the rows for each table
    #   based on the configuration
  end

  it ":replicate_backlog" do
    run_initial_sync
    MiqServer.my_server.update_attribute(:version, "xxx")

    expect {
      run_rake_via_shell("evm:dbsync:replicate_backlog")
    }.to change(RrPendingChange, :count).to(0)
  end

  def insert_initial_records
    @slave_connection.tables.sort.each do |t|
      # Skip metrics subtables, since inserts to the parent table will cascade.
      next if t =~ /^(?:metric_rollups_|metrics_)/
      # Skip tables with data already in them from seeding
      next if row_count(@slave_connection, t) > 0

      conn = @slave_connection
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = t
        singleton_class.send(:define_method, :connection) { conn }
      end
      arel_table = klass.arel_table

      2.times do |n|
        fields = []
        fields << [arel_table[:name],        "#{t}_#{n}"]  if @slave_connection.column_exists?(t, "name")
        fields << [arel_table[:description], "#{t}_#{n}"]  if @slave_connection.column_exists?(t, "description")
        fields << [arel_table[:timestamp],   Time.now.utc] if @slave_connection.column_exists?(t, "timestamp")
        fields << [arel_table[:created_at],  Time.now.utc] if @slave_connection.column_exists?(t, "created_at")
        fields << [arel_table[:updated_at],  Time.now.utc] if @slave_connection.column_exists?(t, "updated_at")
        next if fields.empty?

        klass.all.insert(fields)
      end
    end
  end

  def run_initial_sync
    run_rake_via_shell("evm:dbsync:prepare_replication")
  end

  def assert_replication_enabled
    expect(@slave_connection.tables).to include "#{@rr_prefix}_pending_changes"
    expect(@slave_connection.tables).to include "#{@rr_prefix}_sync_state"
    expect(@slave_connection.tables).to include "#{@rr_prefix}_logged_events"

    # TODO: assert sync_state content
  end

  def assert_initial_replicated_records
    skip "Before cb47c448822, the assertions below weren't running since we weren't populating the initial records. " \
         "Now, they fail sporadically."

    excluded_tables = @replication_config[:exclude_tables].join("|")
    excluded_tables = "^(#{excluded_tables})$"
    excluded_tables_regex = Regexp.new(excluded_tables)

    @slave_connection.tables.sort.each do |t|
      next if t =~ /^rr\d+_/
      next if t == "schema_migrations"

      expected = (t =~ excluded_tables_regex ? 0 : row_count(@slave_connection, t))
      got      = row_count(@master_connection, t)
      expect(got).to eq(expected), "on table: #{t}\nexpected: #{expected}\n     got: #{got} (using ==)"
    end
  end

  #
  # Helper methods
  #

  def run_rake_via_shell(rake_command)
    pid, status = Process.wait2(Kernel.spawn("rake #{rake_command}", :chdir => Rails.root))
    exit(status.exitstatus) if status.exitstatus != 0
  end

  def row_count(connection, table)
    # Use the ONLY clause before the table name to prevent querying dependent tables.
    #   See http://www.postgresql.org/docs/9.0/static/sql-select.html#SQL-FROM
    sql = "SELECT COUNT(*) FROM ONLY #{connection.quote_table_name(table)}"
    connection.select_value(sql).to_i
  end
end
