class CreateCustomizationSpecs < ActiveRecord::Migration
  def self.up
    create_table :customization_specs do |t|
      t.string   :name
      t.bigint   :ems_id
      t.string   :typ
      t.string   :description
      t.datetime :last_update_time
      t.text     :spec
      t.text     :reserved
      t.timestamps
    end
  end

  def self.down
    drop_table :customization_specs
  end
end
