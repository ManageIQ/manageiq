class ChangeDatatypeOfMessageOnMiqTasksTableToText < ActiveRecord::Migration[5.0]
  def up
    change_column :miq_tasks, :message, :text
  end

  def down
    change_column :miq_tasks, :message, :string
  end
end
