class AddProvisionIdxToServiceResources < ActiveRecord::Migration
  def change
    add_column :service_resources, :provision_index, :integer
  end
end