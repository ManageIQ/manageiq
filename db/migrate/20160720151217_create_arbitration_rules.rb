class CreateArbitrationRules < ActiveRecord::Migration[5.0]
  def change
    create_table :arbitration_rules do |t|
      t.string :name
      t.string :description
      t.string :operation
      t.integer :arbitration_profile_id
      t.integer :priority
      t.text :expression

      t.timestamps
    end
  end
end
