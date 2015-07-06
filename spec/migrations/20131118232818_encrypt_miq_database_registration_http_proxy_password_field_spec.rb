require "spec_helper"
require Rails.root.join("db/migrate/20131118232818_encrypt_miq_database_registration_http_proxy_password_field.rb")

describe EncryptMiqDatabaseRegistrationHttpProxyPasswordField do
  let(:miq_database_stub) { migration_stub(:MiqDatabase) }
  let(:password) { "password" }
  let(:enc_pass) { MiqPassword.encrypt(password) }

  migration_context :up do
    it "should encrypt unencrypted password" do
      miq_database_stub.create!(:registration_http_proxy_password => password)

      migrate

      expect(miq_database_stub.first.registration_http_proxy_password).to be_encrypted(password)
    end
  end

  migration_context :down do
    it "should decrypt encrypted password" do
      miq_database_stub.create!(:registration_http_proxy_password => enc_pass)

      migrate

      expect(miq_database_stub.first.registration_http_proxy_password).to eq(password)
    end

    it "should not modify clear text password" do
      miq_database_stub.create!(:registration_http_proxy_password => password)

      migrate

      expect(miq_database_stub.first.registration_http_proxy_password).to eq(password)
    end
  end
end
