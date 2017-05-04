class AddLocalFileToLogFile < ActiveRecord::Migration[4.2]
  def up
    add_column :log_files, :local_file, :string
  end

  def down
    remove_column :log_files, :local_file
  end
end
