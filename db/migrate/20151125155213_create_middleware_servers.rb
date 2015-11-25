class CreateMiddlewareServers < ActiveRecord::Migration
  def change
    create_table :middleware_servers do |t|
      t.string :name       # feed
      t.string :ems_ref    # path
      t.string :nativeid   # id
      t.string :type_path
      t.text   :properties
      t.bigint :ems_id

      t.timestamps
    end
  end
end
