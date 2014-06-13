class AddCloudTenantRefToFloatingIps < ActiveRecord::Migration
  def self.up
    change_table :floating_ips do |t|
      t.belongs_to  :cloud_tenant
    end
  end

  def self.down
    change_table :floating_ips do |t|
      t.remove_belongs_to  :cloud_tenant
    end
  end
end
