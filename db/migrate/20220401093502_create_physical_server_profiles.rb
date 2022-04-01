class CreatePhysicalServerProfiles < ActiveRecord::Migration[6.0]
  def change
    create_table :physical_server_profiles do |t|
      t.references :ems, :type => :bigint, :index => true, :references => :ext_management_system
      t.string :ems_ref
      t.string :name
      t.references :assigned_server, :type => :bigint, :index => true, :references => :physical_server
      t.references :associated_server, :type => :bigint, :index => true, :references => :physical_server

      t.timestamps
    end
  end
end
