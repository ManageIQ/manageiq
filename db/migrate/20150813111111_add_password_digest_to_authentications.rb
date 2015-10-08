class AddPasswordDigestToAuthentications < ActiveRecord::Migration
  def change
    add_column :authentications, :password_digest, :string
  end
end
