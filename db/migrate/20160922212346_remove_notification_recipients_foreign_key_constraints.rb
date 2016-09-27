class RemoveNotificationRecipientsForeignKeyConstraints < ActiveRecord::Migration[5.0]
  def change
    remove_foreign_key :notification_recipients, :notifications
    remove_foreign_key :notification_recipients, :users
  end
end
