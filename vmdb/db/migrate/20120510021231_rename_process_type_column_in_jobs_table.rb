class RenameProcessTypeColumnInJobsTable < ActiveRecord::Migration
  def up
    rename_column :jobs, :process_type, :type
  end

  def down
    rename_column :jobs, :type, :process_type
  end
end
