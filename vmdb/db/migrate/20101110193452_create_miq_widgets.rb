class CreateMiqWidgets < ActiveRecord::Migration
  def self.up
    create_table :miq_widgets do |t|
      t.string    :guid,              :limit => 36
      t.string    :description
      t.string    :title
      t.string    :content_type
      t.text      :options
      t.text      :visibility
      t.bigint    :user_id
      t.bigint    :resource_id
      t.string    :resource_type
      t.bigint    :miq_schedule_id
      t.boolean   :enabled,           :default => true
      t.boolean   :read_only,         :default => false
      t.timestamps
    end
    add_index :miq_widgets, :user_id
  end

  def self.down
    drop_table   :miq_widgets
  end
end
