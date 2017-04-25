class CreateAssetDetails < ActiveRecord::Migration[5.0]
  def change
    create_table :asset_details do |t|
      t.text  :description
			t.text	:contact
      t.text  :location
      t.text  :room
      t.text  :rack_name
      t.text  :lowest_rack_unit
      t.bigint  :resource_id
      t.string  :resource_type
      t.timestamps
      t.index %w(resource_id resource_type), :name => "index_asset_details_on_resource_id_and_resource_type", :using => :btree
    end
  end
end
