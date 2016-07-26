class CreateArbitrationRules < ActiveRecord::Migration[5.0]
  def change
    create_table :arbitration_rules do |t|
      t.string :name
      t.string :description
      t.string :action
      t.integer :arbitration_profile_id
      t.integer :priority
      t.jsonb :expression

      t.timestamps
    end
  end
end
