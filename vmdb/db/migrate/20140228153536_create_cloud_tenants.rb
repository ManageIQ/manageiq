class CreateCloudTenants < ActiveRecord::Migration
  def change
    create_table :cloud_tenants do |t|
      t.string  :name
      t.string  :description
      t.boolean :enabled
      t.string  :ems_ref

      t.belongs_to :ems, :type => :bigint

      t.timestamps :null => true
    end
  end
end
