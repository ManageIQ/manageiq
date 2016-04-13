class AddSubscriptionToExtManagementSystem < ActiveRecord::Migration[5.0]
  def up
    add_column :ext_management_systems, :subscription, :string
  end

  def down
    remove_column :ext_management_systems, :subscription
  end
end
