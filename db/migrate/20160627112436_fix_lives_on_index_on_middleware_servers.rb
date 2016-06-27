class FixLivesOnIndexOnMiddlewareServers < ActiveRecord::Migration[5.0]
  def change
    remove_index :middleware_servers, :column => [:lives_on_type, :lives_on_id ]
    add_index :middleware_servers, [:lives_on_id, :lives_on_type]
  end
end
