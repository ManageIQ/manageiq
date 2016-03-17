class FixHostStorageReplicationOnUpgrade < ActiveRecord::Migration
  include MigrationHelper
  include MigrationHelper::SharedStubs

  class MiqRegion < ActiveRecord::Base; end

  class HostsStorage < ActiveRecord::Base
    self.table_name = "host_storages"
  end

  def up
    if on_replication_target?
      run_for_replication_target
    else
      run_for_replication_source
    end
  end

  def on_replication_target?
    MiqRegion.select(:region).distinct.count > 1
  end

  def run_for_replication_target
    HostsStorage.delete_all
  end

  def run_for_replication_source
    return unless RrSyncState.table_exists?

    prefix = "rr#{ApplicationRecord.my_region_number}"
    old_name = "hosts_storages"
    new_name = "host_storages"

    drop_trigger(new_name, "#{prefix}_#{old_name}")

    say_with_time("Deleting pending changes for #{old_name}") do
      RrPendingChange.where(:change_table => old_name).delete_all
    end

    say_with_time("Deleting sync state for #{old_name}") do
      RrSyncState.where(:table_name => old_name).delete_all
    end

    Rake::Task['evm:dbsync:prepare_replication_without_sync'].invoke
  end
end
