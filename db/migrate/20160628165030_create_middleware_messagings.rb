class CreateMiddlewareMessagings < ActiveRecord::Migration
  def change
    create_table :middleware_messagings do |t|
      t.string :name # name of the messaging
      t.string :ems_ref # path
      t.string :nativeid
      t.string :feed
      t.bigint :server_id
      t.text   :properties
      t.bigint :ems_id
      t.string :messaging_type

      t.timestamps :null => false
    end
  end
end
