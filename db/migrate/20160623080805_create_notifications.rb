class CreateNotifications < ActiveRecord::Migration[5.0]
  def change
    create_table :notifications do |t|
      t.references :user, :foreign_key => true, :type => :bigint
      t.string :level
      t.text :message
      t.boolean :seen

      t.timestamps
    end
  end
end
