class MiqPglogical
  REPLICATION_SET_NAME = 'miq'

  def self.included_tables
    pglogical.tables_in_replication_set(REPLICATION_SET_NAME)
  end

  def self.provider?
    pglogical.configured? && pglogical.replication_sets.include?(REPLICATION_SET_NAME)
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

    def configured_excludes
      MiqServer.my_server.get_config.config
        .fetch_path(:workers, :worker_base, :replication_worker, :replication, :exclude_tables)
    end

    def newly_excluded_tables
      included_tables - configured_excludes
    end

    def newly_included_tables
      (pglogical.connection.tables - configured_excludes) - included_tables
    end
  end
end
