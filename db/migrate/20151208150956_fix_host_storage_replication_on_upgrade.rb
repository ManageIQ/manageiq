class FixHostStorageReplicationOnUpgrade < ActiveRecord::Migration
  include MigrationHelper

  class MiqRegion < ActiveRecord::Base; end

  class HostsStorage < ActiveRecord::Base
    self.table_name = "host_storages"
  end

  def up
    HostsStorage.delete_all if on_replication_target?
  end

  def on_replication_target?
    MiqRegion.select(:region).distinct.count > 1
  end
end
