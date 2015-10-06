class DropTenantResources < ActiveRecord::Migration
  def up
    drop_table :tenant_resources
  end

  def down
    create_table :tenant_resources do |t|
      t.belongs_to :tenant, :type => :bigint
      t.belongs_to :resource, :type => :bigint, :polymorphic => true
    end
  end
end
