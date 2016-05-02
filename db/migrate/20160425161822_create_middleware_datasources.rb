class CreateMiddlewareDatasources < ActiveRecord::Migration
  def change
    create_table :middleware_datasources do |t|
      t.string :name # name of the datasource
      t.string :ems_ref # path
      t.string :nativeid
      t.bigint :server_id
      t.text   :properties
      t.bigint :ems_id

      t.timestamps :null => false
    end
  end
end
