require_relative "./replication_helper"

describe "pglogical replication" do
  let(:slave_db_name)        { Rails.configuration.database_configuration[Rails.env]["database"] }
  let(:master_db_name)       { "#{slave_db_name}_master" }
  let(:replication_set_name) { "test_rep_set" }
  let(:sub_name)             { "test_subscription" }

  let(:excluded_tables_regex) do
    excluded_tables = @replication_config[:exclude_tables].join("|")
    excluded_tables = "^(#{excluded_tables})$"
    Regexp.new(excluded_tables)
  end

  let(:conn_info) do
    config = Rails.configuration.database_configuration[Rails.env]
    dsn = ""
    dsn << "user=#{config["username"]} " if config["username"]
    dsn << "password=#{config["password"]} " if config["password"]
    dsn << "host=#{config["host"]}" if config["host"]
    dsn
  end

  let(:slave_dsn)  { "dbname=#{slave_db_name} #{conn_info}" }
  let(:master_dsn) { "dbname=#{master_db_name} #{conn_info}" }

  before do
    skip "pglogical must be installed" unless ActiveRecord::Base.connection.pglogical.installed?

    MiqRegion.seed
    Zone.seed
    MiqServer.seed

    master_db_config = Rails.configuration.database_configuration[Rails.env].symbolize_keys
                                                                            .merge(:database => master_db_name)

    c = MiqServer.my_server.get_config
    c.config.store_path(:workers, :worker_base, :replication_worker, :replication, :destination, master_db_config)
    c.save

    @replication_config = c.config.fetch_path(:workers, :worker_base, :replication_worker, :replication)

    class ::MasterDb < ActiveRecord::Base; end
    MasterDb.establish_connection(master_db_config)
    @master_connection = MasterDb.connection
    @slave_connection = ActiveRecord::Base.connection

    enable_nodes
  end

  after do
    Object.send(:remove_const, :MasterDb) if defined? MasterDb
    @slave_connection.pglogical.replication_set_drop(replication_set_name)
    @slave_connection.pglogical.node_drop("slave_node")
  end

  # As these tests are not rolled back it makes sense to do the test in one shot and make them order dependant.
  it "replicates" do
    insert_start = 0

    # Test that rows are replicated initially on subscription create
    tables = insert_records(insert_start)
    @master_connection.pglogical.subscription_create(sub_name, slave_dsn, [replication_set_name], false)
    sleep(5)
    assert_records_replicated(tables)
    insert_start += 2

    # Test subscription info methods
    sub_info = @master_connection.pglogical.subscription_show_status(sub_name)
    expect(sub_info["subscription_name"]).to eq(sub_name)
    expect(sub_info["status"]).to eq("replicating")
    expect(sub_info["provider_dsn"]).to eq(slave_dsn)
    expect(sub_info["replication_sets"]).to eq([replication_set_name])

    sub_list = @master_connection.pglogical.subscriptions
    expect(sub_list.first).to eq(sub_info)

    # add a block so that we can be sure we try to clean up the subscription
    # otherwise existing replication connections will prevent us from removing
    # the test master database
    begin
      # Test that rows are replicated as they are inserted when there is an active subscription
      tables = insert_records(insert_start)
      sleep(5)
      assert_records_replicated(tables)
      insert_start += 2

      # Test that no changes are replicated through a disabled subscription
      @master_connection.pglogical.subscription_disable(sub_name)
      tables = insert_records(insert_start)
      assert_records_not_replicated(tables)
      insert_start += 2

      # Test that previous changes are replicated through a re-enabled subscription
      @master_connection.pglogical.subscription_enable(sub_name)
      sleep(5)
      assert_records_replicated(tables)

    ensure
      # Drop the subscription and make sure no more rows are replicated
      @master_connection.pglogical.subscription_drop(sub_name)
      tables = insert_records(insert_start)
      assert_records_not_replicated(tables)
    end
  end

  def insert_records(start = 0)
    tables = []
    @slave_connection.tables.sort.each do |t|
      # Skip metrics subtables, since inserts to the parent table will cascade.
      next if t =~ /^(?:metric_rollups_|metrics_|ar_)/

      conn = @slave_connection
      klass = Class.new(ActiveRecord::Base) do
        self.table_name = t
        singleton_class.send(:define_method, :connection) { conn }
      end
      arel_table = klass.arel_table

      2.times do |n|
        fields = []
        fields << [arel_table[:name],        "#{t}_#{n + start}"]  if @slave_connection.column_exists?(t, "name")
        fields << [arel_table[:description], "#{t}_#{n + start}"]  if @slave_connection.column_exists?(t, "description")
        fields << [arel_table[:timestamp],   Time.now.utc] if @slave_connection.column_exists?(t, "timestamp")
        fields << [arel_table[:created_at],  Time.now.utc] if @slave_connection.column_exists?(t, "created_at")
        fields << [arel_table[:updated_at],  Time.now.utc] if @slave_connection.column_exists?(t, "updated_at")
        next if fields.empty?

        klass.all.insert(fields)
        tables << t
      end
    end
    tables
  end

  # Asserts that for all tables in the given list the table is either
  # excluded and has no rows in the master or is included and the
  # master has the same number of rows as the slave
  def assert_records_replicated(tables)
    tables.sort.each do |t|
      expected = (t =~ excluded_tables_regex ? 0 : row_count(@slave_connection, t))
      got      = row_count(@master_connection, t)
      expect(got).to eq(expected), "on table: #{t}\nexpected: #{expected}\n     got: #{got} (using ==)"
    end
  end

  # asserts that there are more rows on the slave than the master for
  # non-excluded tables in the given list
  def assert_records_not_replicated(tables)
    tables.sort.each do |t|
      next if t =~ excluded_tables_regex

      slave_count  = row_count(@slave_connection, t)
      master_count = row_count(@master_connection, t)
      expect(slave_count).to be > master_count, "on table: #{t}\nexpected: #{slave_count} > #{master_count}\n"
    end
  end

  def enable_nodes
    @slave_connection.pglogical.enable
    @master_connection.pglogical.enable

    @slave_connection.pglogical.node_create("slave_node", slave_dsn)
    @master_connection.pglogical.node_create("master_node", master_dsn)

    @slave_connection.pglogical.replication_set_create(replication_set_name)
    @slave_connection.tables.sort.each do |t|
      next if @replication_config[:exclude_tables].include?(t)
      @slave_connection.pglogical.replication_set_add_table(replication_set_name, t)
    end
  end

  #
  # Helper methods
  #

  def row_count(connection, table)
    # Use the ONLY clause before the table name to prevent querying dependent tables.
    #   See http://www.postgresql.org/docs/9.0/static/sql-select.html#SQL-FROM
    sql = "SELECT COUNT(*) FROM ONLY #{connection.quote_table_name(table)}"
    connection.select_value(sql).to_i
  end
end
