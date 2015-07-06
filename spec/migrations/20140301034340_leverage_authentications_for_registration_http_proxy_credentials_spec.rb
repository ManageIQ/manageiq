require 'spec_helper'
require Rails.root.join("db/migrate/20140301034340_leverage_authentications_for_registration_http_proxy_credentials.rb")

describe LeverageAuthenticationsForRegistrationHttpProxyCredentials do
  let(:auth_stub) { migration_stub(:Authentication) }
  let(:db_stub) { migration_stub(:MiqDatabase) }

  migration_context :up do
    it "Moves registration_http_proxy credentials to an authentication" do
      db_stub.create!(
        :registration_http_proxy_username => "abc",
        :registration_http_proxy_password => MiqPassword.encrypt("def")
      )

      migrate

      # Expect counts
      expect(auth_stub.count).to  eq(1)
      expect(db_stub.count).to    eq(1)

      # Expect data
      auth = auth_stub.first
      db   = db_stub.first

      expect(auth.userid).to eq("abc")
      expect(MiqPassword.decrypt(auth.password)).to eq("def")
      expect { db.registration_http_proxy_username }.to raise_error(NoMethodError)
      expect { db.registration_http_proxy_password }.to raise_error(NoMethodError)
    end
  end

  migration_context :down do
    it "Moves registration_http_proxy credentials from Authentications to MiqDatabases" do
      db = db_stub.create!
      auth_stub.create!(
        :authtype      => "registration_http_proxy",
        :name          => "MiqDatabase vmdb_development",
        :userid        => "abc",
        :password      => MiqPassword.encrypt("def"),
        :resource_id   => db.id,
        :resource_type => "MiqDatabase",
        :type          => "AuthUseridPassword"
      )

      migrate

      # Expect counts
      expect(auth_stub.count).to  eq(0)
      expect(db_stub.count).to    eq(1)

      # Expect data
      db = db.reload
      expect(db.registration_http_proxy_username).to                       eq("abc")
      expect(MiqPassword.decrypt(db.registration_http_proxy_password)).to  eq("def")
    end
  end
end
