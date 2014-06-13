class AddCloudTenantRefToSecurityGroups < ActiveRecord::Migration
  def self.up
    change_table :security_groups do |t|
      t.belongs_to  :cloud_tenant
    end
  end

  def self.down
    change_table :security_groups do |t|
      t.remove_belongs_to  :cloud_tenant
    end
  end
end
