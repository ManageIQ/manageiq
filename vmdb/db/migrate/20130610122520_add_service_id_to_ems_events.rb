class AddServiceIdToEmsEvents < ActiveRecord::Migration

  def change
    add_column  :ems_events,   :service_id,  :bigint
    add_index   :ems_events,   :service_id
  end

end