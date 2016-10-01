class RemoveNotificationsForeignKeyConstraints < ActiveRecord::Migration[5.0]
  def change
    remove_foreign_key :notifications, :notification_types
    remove_foreign_key :notifications, :users
  end
end
