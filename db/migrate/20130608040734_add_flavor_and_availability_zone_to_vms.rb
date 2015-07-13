class AddFlavorAndAvailabilityZoneToVms < ActiveRecord::Migration
  def change
    add_column :vms, :flavor_id, :bigint
    add_index  :vms, :flavor_id

    add_column :vms, :availability_zone_id, :bigint
    add_index  :vms, :availability_zone_id
  end
end
