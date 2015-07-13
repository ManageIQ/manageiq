class AddCloudTenantRefToCloudNetworks < ActiveRecord::Migration
  def self.up
    change_table :cloud_networks do |t|
      t.belongs_to  :cloud_tenant, :type => :bigint
    end
  end

  def self.down
    change_table :cloud_networks do |t|
      t.remove_belongs_to  :cloud_tenant
    end
  end
end
