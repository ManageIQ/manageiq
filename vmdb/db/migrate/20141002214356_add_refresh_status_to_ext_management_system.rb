class AddRefreshStatusToExtManagementSystem < ActiveRecord::Migration
  def change
    add_column :ext_management_systems, :last_refresh_error, :text
    add_column :ext_management_systems, :last_refresh_date,  :timestamp
  end
end
