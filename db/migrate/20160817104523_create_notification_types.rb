class CreateNotificationTypes < ActiveRecord::Migration[5.0]
  def change
    create_table :notification_types do |t|
      t.string :name, :limit => 64
      t.string :level, :limit => 16
      t.string :audience, :limit => 16
      t.text :message
      t.integer :expires_in
    end
    add_index :notification_types, :name, :unique => true
  end
end
