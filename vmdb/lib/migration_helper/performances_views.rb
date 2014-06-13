# These are here for handling old migrations.  If we want full views
# support, consider using the rails_sql_views gem.

module MigrationHelper::PerformancesViews
  def view_exists?(view)
    say_with_time("view_exists?(:#{view})") do
      connection.select_value("SELECT COUNT(*) FROM INFORMATION_SCHEMA.VIEWS WHERE table_name = #{connection.quote(view)}").to_i > 0
    end
  end

  def create_view(view, select)
    return if view_exists?(view)
    say_with_time("create_view(:#{view})") do
      connection.execute("CREATE VIEW #{view} AS #{select}")
    end
  end

  def drop_view(view)
    return unless view_exists?(view)
    say_with_time("drop_view(:#{view})") do
      connection.execute("DROP VIEW #{view}")
    end
  end

  def drop_performances_views
    drop_view :vm_performances
    drop_view :host_performances
    drop_view :ems_cluster_performances
    drop_view :storage_performances
  end

  def create_performances_views
    create_view :vm_performances,          "select * from vim_performances where resource_type = 'Vm' and resource_id IS NOT NULL"
    create_view :host_performances,        "select * from vim_performances where resource_type = 'Host' and resource_id IS NOT NULL"
    create_view :ems_cluster_performances, "select * from vim_performances where resource_type = 'EmsCluster' and resource_id IS NOT NULL"
    create_view :storage_performances,     "select * from vim_performances where resource_type = 'Storage' and resource_id IS NOT NULL"
  end
end
