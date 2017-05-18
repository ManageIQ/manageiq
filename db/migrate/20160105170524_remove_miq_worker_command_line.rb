class RemoveMiqWorkerCommandLine < ActiveRecord::Migration[4.2]
  def up
    remove_column :miq_workers, :command_line
  end

  def down
    add_column :miq_workers, :command_line, :string, :limit => 512
  end
end
