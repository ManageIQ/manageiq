require 'bcrypt'

class MigrateToBcryptPassword < ActiveRecord::Migration

  class User < ActiveRecord::Base; end

  def up
    add_column   :users, :password_digest, :string
    User.all.each do |user|
      # with has_secure_password, password is required. Use
      # "dummy" when no password is present
      decrypted_password = user.read_attribute(:password).blank? ? "dummy" :
                           MiqPassword.decrypt(user.read_attribute(:password))

      password = BCrypt::Password.create(decrypted_password)
      user.update_attribute(:password_digest, password)
      # sync admin password
      if user.userid == "admin"
        sync_admin_password(user)
      end
    end
    remove_column :users, :password
  end

  def down
    remove_column :users, :password_digest
    add_column    :users, :password, :string
  end

  def sync_admin_password(user)
    fd = File.open(File.join(Rails.root, "config/miq_pass"), 'w')
    fd.puts user.read_attribute(:password_digest)
  ensure
    fd.close unless fd.nil?
  end
end
