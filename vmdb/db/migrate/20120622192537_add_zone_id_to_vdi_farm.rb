class AddZoneIdToVdiFarm < ActiveRecord::Migration
  def change
    add_column :vdi_farms, :zone_id, :bigint
  end
end
