class CreateShowbackConfigurations < ActiveRecord::Migration[5.0]
  def up
    create_table :showback_configurations do |t|
      t.string     :name
      t.string     :description
      t.string     :measure
      t.text       :types
      t.timestamp  :updated_at
      t.timestamp  :created_at
    end
  end

  def down
    drop_table :showback_configurations
  end
end
