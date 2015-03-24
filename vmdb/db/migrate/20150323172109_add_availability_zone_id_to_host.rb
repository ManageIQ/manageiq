class AddAvailabilityZoneIdToHost < ActiveRecord::Migration
  def change
    add_column :hosts, :availability_zone_id, :bigint
    add_index  :hosts, :availability_zone_id
  end
end
