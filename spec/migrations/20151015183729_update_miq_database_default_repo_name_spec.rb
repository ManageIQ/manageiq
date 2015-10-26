require "spec_helper"
require_migration

describe UpdateMiqDatabaseDefaultRepoName do
  let(:db_stub) { migration_stub(:MiqDatabase) }

  migration_context :up do
    it "migrates the 5.4 repos to 5.5 repos for Sat6 and hosted" do
      old_repos = "cf-me-5.4-for-rhel-6-rpms rhel-server-rhscl-6-rpms"
      new_repos = "cf-me-5.5-for-rhel-7-rpms rhel-server-rhscl-7-rpms"
      db = db_stub.create!(:update_repo_name => old_repos)

      migrate

      expect(db.reload.update_repo_name).to eq(new_repos)
    end

    it "removes Sat5 registration info" do
      db = db_stub.create!(
        :registration_type                      => "rhn_satellite",
        :registration_organization              => "org",
        :registration_server                    => "serv",
        :registration_http_proxy_server         => "a.proxy",
        :update_repo_name                       => "repo",
        :registration_organization_display_name => "name"
      )
      Authentication.create!(
        :resource_type => 'MiqDatabase',
        :resource_id   => db.id,
        :authtype      => :registration_http_proxy,
        :name          => "auth"
      )
      Authentication.create!(
        :resource_type => 'MiqDatabase',
        :resource_id   => db.id,
        :authtype      => :registration,
        :name          => "auth2"
      )
      default_auth = Authentication.create!(
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

      auths = Authentication.where(:resource_type => 'MiqDatabase', :resource_id => db.id)
      expect(auths).to match_array([default_auth])
    end
  end
end
