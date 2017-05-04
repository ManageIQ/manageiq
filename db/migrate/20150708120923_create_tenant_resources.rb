class CreateTenantResources < ActiveRecord::Migration[4.2]
  def change
    create_table :tenant_resources do |t|
      t.belongs_to :tenant, :type => :bigint
      t.belongs_to :resource, :type => :bigint, :polymorphic => true
    end
  end
end
