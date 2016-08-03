class CreateMiddlewareServerGroups < ActiveRecord::Migration[5.0]
  def change
    create_table :middleware_server_groups do |t|
      t.string :name # name of the server group
      t.string :ems_ref # path
      t.string :nativeid
      t.string :feed
      t.string :type_path
      t.string :profile
      t.text   :properties
      t.bigint :domain_id

      t.timestamps :null => false
    end
  end
end
