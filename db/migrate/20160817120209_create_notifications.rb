class CreateNotifications < ActiveRecord::Migration[5.0]
  def change
    create_table :notifications do |t|
      t.references :notification_type, :foreign_key => true, :type => :bigint, :null => false
      t.references :user, :foreign_key => true, :type => :bigint
      t.references :subject, :polymorphic => true, :type => :bigint
      t.references :cause, :polymorphic => true, :type => :bigint

      t.timestamps
    end
  end
end
