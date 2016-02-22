class MiqPglogical
  REPLICATION_SET_NAME = 'miq'

  def self.included_tables
    pglogical.tables_in_replication_set(REPLICATION_SET_NAME)
  end

  def self.configured_excludes
    MiqServer.my_server.get_config.config
      .fetch_path(:workers, :worker_base, :replication_worker, :replication, :exclude_tables)
  end

  def self.provider?
    pglogical.installed? && pglogical.enabled? && pglogical.replication_sets.include?(REPLICATION_SET_NAME)
  end

  def self.create_local_node
    pglogical.node_create("region_#{ApplicationRecord.my_region_number}", local_node_dsn)
  end

  def self.create_replication_set
    pglogical.replication_set_create(REPLICATION_SET_NAME)
    refresh_excludes
  end

  def self.refresh_excludes
    # remove newly excluded tables from replication set
    newly_excluded_tables.each do |table|
      pglogical.replication_set_remove_table(REPLICATION_SET_NAME, table)
    end

    # add tables to the set which are no longer excluded (or new)
    newly_included_tables.each do |table|
      pglogical.replication_set_add_table(REPLICATION_SET_NAME, table)
    end
  end

  class << self
    private

    def pglogical(refresh = false)
      return @pglogical = ActiveRecord::Base.connection.pglogical if refresh
      @pglogical ||= ActiveRecord::Base.connection.pglogical
    end

    # tables that are currently included, but we want them excluded
    def newly_excluded_tables
      included_tables & configured_excludes
    end

    # tables that are currently excluded, but we want them included
    def newly_included_tables
      (pglogical.connection.tables - configured_excludes) - included_tables
    end

    def local_node_dsn
      config = Rails.configuration.database_configuration[Rails.env]
      dsn = "dbname=#{config["database"]}"
      dsn << " user=#{config["username"]}" if config["username"]
      dsn << " password=#{config["password"]}" if config["password"]
      dsn << " host=#{config["host"]}" if config["host"]
      dsn
    end
  end
end
