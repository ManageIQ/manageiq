class CreateMiddlewareServers < ActiveRecord::Migration
  def change
    create_table :middleware_servers do |t|
      t.string :name       # server name generated from id
      t.string :feed       # feed
      t.string :ems_ref    # path
      t.string :nativeid   # id
      t.string :type_path
      t.string :host
      t.string :product
      t.text   :properties
      t.bigint :ems_id

      t.timestamps :null => false
    end
  end
end
