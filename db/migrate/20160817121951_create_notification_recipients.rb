class CreateNotificationRecipients < ActiveRecord::Migration[5.0]
  def change
    create_table :notification_recipients do |t|
      t.references :notification, :foreign_key => true, :type => :bigint
      t.references :user, :foreign_key => true, :type => :bigint
      t.boolean :seen
    end
  end
end
