class AddOptionsToNotifications < ActiveRecord::Migration[5.0]
  def change
    add_column :notifications, :options, :text
  end
end
