class CreateBlueprints < ActiveRecord::Migration[5.0]
  def change
    create_table :blueprints do |t|
      t.string :name
      t.string :description
      t.string :status
      t.string :version
      t.jsonb  :ui_properties

      t.timestamps
    end
    add_index :blueprints, :name
    add_index :blueprints, :status
  end
end
