class LeverageAuthenticationsForRegistrationHttpProxyCredentials < ActiveRecord::Migration
  class MiqDatabase < ActiveRecord::Base; end
  class Authentication < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    say_with_time("Leverage Authentication mixin for registration_http_proxy credentials") do
      MiqDatabase.all.each do |db|
        Authentication.create(
          :authtype      => "registration_http_proxy",
          :name          => "MiqDatabase vmdb_development",
          :userid        => db.registration_http_proxy_username,
          :password      => MiqPassword.try_encrypt(db.registration_http_proxy_password),
          :resource_id   => db.id,
          :resource_type => "MiqDatabase",
          :type          => "AuthUseridPassword"
        )
      end
    end

    remove_column :miq_databases, :registration_http_proxy_username
    remove_column :miq_databases, :registration_http_proxy_password
  end

  def down
    add_column :miq_databases, :registration_http_proxy_username, :string
    add_column :miq_databases, :registration_http_proxy_password, :string

    say_with_time("Move registration_http_proxy credentials from Authentication to MiqDatabase record") do
      MiqDatabase.all.each do |db|
        auth = Authentication.where(
          :authtype      => "registration_http_proxy",
          :resource_type => "MiqDatabase",
          :resource_id   => db.id,
        ).first

        db.update_attributes(
          :registration_http_proxy_username => auth.userid,
          :registration_http_proxy_password => MiqPassword.try_encrypt(auth.password)
        )

        auth.destroy
      end
    end
  end
end
