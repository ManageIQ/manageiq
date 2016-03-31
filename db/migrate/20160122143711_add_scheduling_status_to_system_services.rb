class AddSchedulingStatusToSystemServices < ActiveRecord::Migration
  def change
    add_column :system_services, :scheduling_status, :string
  end
end
