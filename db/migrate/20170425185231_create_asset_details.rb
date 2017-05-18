class CreateAssetDetails < ActiveRecord::Migration[5.0]
  def change
    create_table :asset_details do |t|
      t.text  :description
      t.text  :contact
      t.text  :location
      t.text  :room
      t.text  :rack_name
      t.text  :lowest_rack_unit
      t.bigint  :resource_id
      t.string  :resource_type
      t.timestamps
      t.index %w(resource_id resource_type)
    end
  end
end
