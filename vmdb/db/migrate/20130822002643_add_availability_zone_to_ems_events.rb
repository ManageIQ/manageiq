class AddAvailabilityZoneToEmsEvents < ActiveRecord::Migration
  def change
    add_column :ems_events, :availability_zone_id, :bigint
  end
end
