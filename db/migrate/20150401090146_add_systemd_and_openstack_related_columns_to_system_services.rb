class AddSystemdAndOpenstackRelatedColumnsToSystemServices < ActiveRecord::Migration[4.2]
  def change
    add_column :system_services, :systemd_load, :string
    add_column :system_services, :systemd_active, :string
    add_column :system_services, :systemd_sub, :string
  end
end
