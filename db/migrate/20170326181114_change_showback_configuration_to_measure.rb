class ChangeShowbackConfigurationToMeasure < ActiveRecord::Migration[5.0]
  def up
    remove_index   :showback_events, :showback_configuration_id
    remove_column  :showback_events, :showback_configuration_id, :bigint
    drop_table :showback_configurations
    create_table :showback_measure_types, id: :bigserial, force: :cascade do |t|
      t.string     :category
      t.string     :description
      t.string     :measure
      t.text       :dimensions, array: true, default: []
      t.timestamp  :updated_at
      t.timestamp  :created_at
    end
  end

  def down
    create_table :showback_configurations, id: :bigserial, force: :cascade do |t|
      t.string     :name
      t.string     :description
      t.string     :measure
      t.text       :types
      t.timestamp  :updated_at
      t.timestamp  :created_at
    end
    add_column :showback_events, :showback_configuration_id, :bigint
    add_index  :showback_events, :showback_configuration_id
    drop_table :showback_measure_types
  end
end
