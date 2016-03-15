require_migration

describe RemoveSat5RepoConfig do
  let(:db_stub) { migration_stub(:MiqDatabase) }
  let(:authentication_stub) { migration_stub(:Authentication) }

  migration_context :up do
    it "removes Sat5 registration info" do
      db = db_stub.create!(
        :registration_type                      => "rhn_satellite",
        :registration_organization              => "org",
        :registration_server                    => "serv",
        :registration_http_proxy_server         => "a.proxy",
        :update_repo_name                       => "repo",
        :registration_organization_display_name => "name"
      )
      authentication_stub.create!(
        :resource_type => 'MiqDatabase',
        :resource_id   => db.id,
        :authtype      => :registration_http_proxy,
        :name          => "auth"
      )
      authentication_stub.create!(
        :resource_type => 'MiqDatabase',
        :resource_id   => db.id,
        :authtype      => :registration,
        :name          => "auth2"
      )
      default_auth = authentication_stub.create!(
        :resource_type => 'MiqDatabase',
        :resource_id   => db.id,
        :authtype      => :default,
        :name          => "auth3"
      )

      migrate
      db.reload

      expect(db).to have_attributes(
        :registration_type                      => nil,
        :registration_organization              => nil,
        :registration_server                    => nil,
        :registration_http_proxy_server         => nil,
        :update_repo_name                       => "cf-me-5.5-for-rhel-7-rpms rhel-server-rhscl-7-rpms",
        :registration_organization_display_name => nil
      )

      auths = authentication_stub.where(:resource_type => 'MiqDatabase', :resource_id => db.id)
      expect(auths).to match_array([default_auth])
    end
  end
end
