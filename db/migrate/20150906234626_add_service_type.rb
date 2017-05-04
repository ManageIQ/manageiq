class AddServiceType < ActiveRecord::Migration[4.2]
  def change
    add_column :container_services, :service_type, :string
  end
end
