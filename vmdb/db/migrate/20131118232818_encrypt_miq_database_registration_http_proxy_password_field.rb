class EncryptMiqDatabaseRegistrationHttpProxyPasswordField < ActiveRecord::Migration
  class MiqDatabase < ActiveRecord::Base; end

  def up
    say_with_time("Encrypt miq_database registration_http_proxy_password field") do
      MiqDatabase.all.each do |db|
        db.update_attribute(:registration_http_proxy_password, MiqPassword.encrypt(db.registration_http_proxy_password)) unless MiqPassword.encrypted?(db.registration_http_proxy_password)
      end
    end
  end

  def down
    say_with_time("Decrypt miq_database registration_http_proxy_password field") do
      MiqDatabase.all.each do |db|
        db.update_attribute(:registration_http_proxy_password, MiqPassword.decrypt(db.registration_http_proxy_password)) if MiqPassword.encrypted?(db.registration_http_proxy_password)
      end
    end
  end
end
