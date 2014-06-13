class CreateMiqDialogs < ActiveRecord::Migration
  def self.up
    create_table :miq_dialogs do |t|
      t.string     :name
      t.string     :description
      t.string     :dialog_type
      t.text       :content
      t.boolean    :default,           :default => false
      t.string     :filename
      t.datetime   :file_mtime
      t.timestamps
    end
  end

  def self.down
    drop_table :miq_dialogs
  end
end
