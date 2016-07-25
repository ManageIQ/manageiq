class CreateArbitrationRules < ActiveRecord::Migration[5.0]
  def change
    create_table :arbitration_rules do |t|
      t.string :type
      t.string :name
      t.string :object_attribute
      t.string :condition
      t.string :object_attribute_value
      t.string :action
      t.integer :arbitration_profile_id
      t.integer :priority
      t.timestamp :created_on
      t.timestamp :updated_on
    end
  end
end
