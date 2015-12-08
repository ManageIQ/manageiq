class CreateSettingsChangesTable < ActiveRecord::Migration
  def up
    create_table :settings_changes do |t|
      t.belongs_to :resource, :type => :bigint, :polymorphic => true
      t.string     :name
      t.string     :key
      t.text       :value
      t.timestamps
    end
    add_index :settings_changes, :key
    add_index :settings_changes, [:resource_id, :resource_type]
  end

  def down
    drop_table :settings_changes
  end
end
