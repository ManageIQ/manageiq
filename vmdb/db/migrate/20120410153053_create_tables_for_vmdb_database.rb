class CreateTablesForVmdbDatabase < ActiveRecord::Migration
  def up
    create_table   :vmdb_databases do |t|
      t.string     :name
      t.string     :ipaddress
      t.string     :vendor
      t.string     :version
      t.string     :path
      t.datetime   :last_start_time
    end

    create_table :vmdb_database_metrics do |t|
      t.belongs_to :vmdb_database
      t.float      :disk_size
      t.float      :allocated_size
      t.float      :used_size
      t.integer    :processses_running
      t.integer    :active_connections
      t.datetime   :timestamp
    end

    create_table :vmdb_tables do |t|
      t.belongs_to :vmdb_database
      t.string     :name
      t.string     :table_type
      t.bigint     :parent_id
    end

    create_table :vmdb_indexes do |t|
      t.belongs_to :vmdb_table
      t.string     :name
    end

    create_table :vmdb_metrics do |t|
      t.belongs_to :resource, :polymorphic => true
      t.float      :size
      t.bigint     :rows
      t.bigint     :pages
      t.float      :percent_bloat
      t.float      :wasted_bytes
      t.integer    :otta
      t.bigint     :table_scan
      t.bigint     :sequential_rows_read
      t.bigint     :index_scan
      t.bigint     :index_rows_fetched
      t.bigint     :rows_inserted
      t.bigint     :rows_updated
      t.bigint     :rows_deleted
      t.bigint     :rows_hot_updated
      t.bigint     :rows_live
      t.bigint     :rows_dead
      t.datetime   :last_vacuum_date
      t.datetime   :last_autovacuum_date
      t.datetime   :last_analyze_date
      t.datetime   :last_autoanalyze_date
      t.datetime   :timestamp
    end

    add_index :vmdb_metrics, [:resource_id, :resource_type, :timestamp], :name => "index_vmdb_metrics_on_resource_and_timestamp"

  end

  def down
    drop_table :vmdb_databases

    drop_table :vmdb_database_metrics

    drop_table :vmdb_tables

    drop_table :vmdb_indexes

    remove_index :vmdb_metrics, :name => "index_vmdb_metrics_on_resource_and_timestamp"
    drop_table :vmdb_metrics
  end

end
