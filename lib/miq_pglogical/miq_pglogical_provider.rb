class MiqPglogicalProvider < MiqPglogical
  def configure_provider
    return if provider?
    pglogical.enable
    create_node
    create_replication_set
  end

  def destroy_provider
    return unless provider?
    pglogical.replication_set_drop(REPLICATION_SET_NAME)
    drop_node
  end

  # Lists the tables currently being replicated by pglogical
  # @return Array<String> the table list
  def included_tables
    pglogical.tables_in_replication_set(REPLICATION_SET_NAME)
  end

  # Lists the tables configured to be excluded in the vmdb configuration
  # @return Array<String> the table list
  def configured_excludes
    MiqServer.my_server.get_config.config.fetch_path(*SETTINGS_PATH, :exclude_tables)
  end

  # Creates the 'miq' replication set and refreshes the excluded tables
  def create_replication_set
    pglogical.replication_set_create(REPLICATION_SET_NAME)
    refresh_excludes
  end

  # Aligns the contents of the 'miq' replication set with the currently configured vmdb excludes
  def refresh_excludes
    # remove newly excluded tables from replication set
    newly_excluded_tables.each do |table|
      pglogical.replication_set_remove_table(REPLICATION_SET_NAME, table)
    end

    # add tables to the set which are no longer excluded (or new)
    newly_included_tables.each do |table|
      pglogical.replication_set_add_table(REPLICATION_SET_NAME, table)
    end
  end

  private

  # tables that are currently included, but we want them excluded
  def newly_excluded_tables
    included_tables & configured_excludes
  end

  # tables that are currently excluded, but we want them included
  def newly_included_tables
    (@connection.tables - configured_excludes) - included_tables
  end
end
