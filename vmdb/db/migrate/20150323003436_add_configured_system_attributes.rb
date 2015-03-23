class AddConfiguredSystemAttributes < ActiveRecord::Migration
  def change
    add_column :configured_systems, :ipaddress, :string
    add_column :configured_systems, :mac_address, :string
    add_column :configured_systems, :ipmi_present, :boolean
    add_column :configured_systems, :puppet_status, :string
    add_column :configured_systems, :customization_script_ptable_id, :bigint
    add_column :configured_systems, :customization_script_medium_id, :bigint
  end
end
