class RemoveMessageAndMonitorStatusColumnsFromMiqWorkersTable < ActiveRecord::Migration
  def up
    remove_column :miq_workers, :message
    remove_column :miq_workers, :monitor_status
  end

  def down
    add_column    :miq_workers, :message,        :string
    add_column    :miq_workers, :monitor_status, :string
  end
end
