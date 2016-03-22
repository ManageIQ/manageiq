class AddDeploymentClassificationToVm < ActiveRecord::Migration[5.0]
  def change
    add_column :vms, :classification, :string
    add_reference :vms, :deployment, index: true
  end
end
