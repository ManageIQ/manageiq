class AddFileDepotIdToLogFile < ActiveRecord::Migration[4.2]
  def up
    add_column :log_files, :file_depot_id, :bigint
  end

  def down
    remove_column :log_files, :file_depot_id
  end
end
