class AddAuthKeyToAuthentications < ActiveRecord::Migration
  def up
    add_column :authentications, :auth_key, :text
  end

  def down
    remove_column :authentications, :auth_key
  end
end
