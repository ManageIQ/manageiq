require Rails.root.join('lib/migration_helper')

class RenameStatesToDriftStates < ActiveRecord::Migration
  include MigrationHelper::SharedStubs

  def up
    remove_index :states, :name => 'index_states_on_resource_id_and_resource_type_and_timestamp'
    rename_table :states, :drift_states
    add_index :drift_states, [:resource_id, :resource_type, :timestamp], :name => 'index_states_on_resource_id_and_resource_type_and_timestamp'

    if RrPendingChange.table_exists?
      say_with_time("Renaming state to drift_state in '#{RrPendingChange.table_name}'") do
        RrPendingChange.where(:change_table => "state").update_all(:change_table => "drift_state")
      end

      say_with_time("Renaming state to drift_state in '#{RrSyncState.table_name}'") do
        RrSyncState.where(:table_name => "state").update_all(:table_name => "drift_state")
      end
    end
  end

  def down
    remove_index :drift_states, :name => 'index_states_on_resource_id_and_resource_type_and_timestamp'
    rename_table :drift_states, :states
    add_index :states, [:resource_id, :resource_type, :timestamp], :name => 'index_states_on_resource_id_and_resource_type_and_timestamp'

    if RrPendingChange.table_exists?
      say_with_time("Renaming drift_state to state in '#{RrPendingChange.table_name}'") do
        RrPendingChange.where(:change_table => "drift_state").update_all(:change_table => "state")
      end

      say_with_time("Renaming drift_state to state in '#{RrSyncState.table_name}'") do
        RrSyncState.where(:table_name => "drift_state").update_all(:table_name => "state")
      end
    end
  end
end
