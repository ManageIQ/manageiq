class AddProvisionCostToServiceTemplates < ActiveRecord::Migration
  def change
    add_column :service_templates, :provision_cost, :float
  end
end
