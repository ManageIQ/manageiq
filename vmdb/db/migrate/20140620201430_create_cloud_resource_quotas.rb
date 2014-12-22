class CreateCloudResourceQuotas < ActiveRecord::Migration
  def up
    create_table :cloud_resource_quotas do |t|
      t.string  :ems_ref
      t.string  :service_name
      t.string  :name
      t.integer :value
      t.string  :type

      t.belongs_to :ems,          :type => :bigint
      t.belongs_to :cloud_tenant, :type => :bigint

      t.timestamps
    end
  end

  def down
    drop_table :cloud_resource_quotas
  end
end
