class CreateEmsConnections < ActiveRecord::Migration
  def change
    create_table :ems_connections do |t|
      t.string :type
      t.integer :port
      t.integer :ems_id
      t.integer :resource_id
      t.string :ipaddress

      t.timestamps
    end
  end
end
