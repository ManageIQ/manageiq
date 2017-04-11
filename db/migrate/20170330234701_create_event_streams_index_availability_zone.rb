class CreateEventStreamsIndexAvailabilityZone < ActiveRecord::Migration[5.0]
  def change
    add_index :event_streams, [:availability_zone_id, :type]
  end
end
