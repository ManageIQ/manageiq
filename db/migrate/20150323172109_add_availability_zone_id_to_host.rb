class AddAvailabilityZoneIdToHost < ActiveRecord::Migration[4.2]
  def change
    add_column :hosts, :availability_zone_id, :bigint
    add_index  :hosts, :availability_zone_id
  end
end
