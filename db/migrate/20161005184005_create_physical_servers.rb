class CreatePhysicalServers < ActiveRecord::Migration[5.0]
  def change
    create_table :physical_servers do |t|
      t.bigint :ems_id
      t.string :name
      t.string :type
      t.string :uid_ems
      t.string :ems_ref
      t.timestamps
    end
  end
  end
