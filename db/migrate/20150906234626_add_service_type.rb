class AddServiceType < ActiveRecord::Migration
  def change
    add_column :container_services, :service_type, :string
  end
end
