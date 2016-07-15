class CreateArbitrationSettings < ActiveRecord::Migration[5.0]
  def change
    create_table :arbitration_settings do |t|
      t.string :name
      t.string :display_name
      t.text :value
      t.datetime :created_on
      t.datetime :updated_on
    end
  end
end
