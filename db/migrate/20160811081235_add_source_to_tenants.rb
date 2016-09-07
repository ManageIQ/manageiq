class AddSourceToTenants < ActiveRecord::Migration[5.0]
  def change
    add_reference :tenants, :source, :type => :bigint, :polymorphic => true
  end
end
