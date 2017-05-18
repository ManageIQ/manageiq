class RemoveServiceIdFromEmsEvents < ActiveRecord::Migration[4.2]
  def up
    remove_index  :ems_events, :service_id
    remove_column :ems_events, :service_id
  end

  def down
    add_column :ems_events, :service_id, :bigint
    add_index  :ems_events, :service_id
  end
end
