class UpdateLogCollectionPathInConfigurationsSettings < ActiveRecord::Migration
  class Configuration < ActiveRecord::Base
    serialize :settings
    self.inheritance_column = :_type_disabled # disable STI
  end

  NEW_PG_CONF_PATH = "/opt/rh/postgresql92/root/var/lib/pgsql/data/*.conf"
  NEW_PG_LOGS_PATH = "/opt/rh/postgresql92/root/var/lib/pgsql/data/pg_log/*"
  OLD_PG_CONF_PATH = "/var/lib/pgsql/data/*.conf"
  OLD_PG_LOGS_PATH = "/var/lib/pgsql/data/serverlog*"

  def up
    say_with_time("Updating PG paths in VMDB configurations") { change_pg_log_paths("OLD", "NEW") }
  end

  def down
    say_with_time("Reverting PG paths in VMDB configurations") { change_pg_log_paths("NEW", "OLD") }
  end

  def change_pg_log_paths(current_path, desired_path)
    Configuration.where(:typ => "vmdb").each do |c|
      path = ["log", "collection", :current, :pattern]
      pg_conf_index = c.settings.fetch_path(path).try(:index, self.class.const_get("#{current_path}_PG_CONF_PATH"))
      pg_logs_index = c.settings.fetch_path(path).try(:index, self.class.const_get("#{current_path}_PG_LOGS_PATH"))

      c.settings.store_path(path.dup.push(pg_conf_index), self.class.const_get("#{desired_path}_PG_CONF_PATH")) if pg_conf_index
      c.settings.store_path(path.dup.push(pg_logs_index), self.class.const_get("#{desired_path}_PG_LOGS_PATH")) if pg_logs_index
      c.save
    end
  end
end
