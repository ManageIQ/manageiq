class RemoveSat5RepoConfig < ActiveRecord::Migration
  class MiqDatabase < ActiveRecord::Base; end

  class Authentication < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  def up
    say_with_time("Removing Sat5 update configuration") do
      return unless (db = MiqDatabase.first)

      new_repos = "cf-me-5.5-for-rhel-7-rpms rhel-server-rhscl-7-rpms"

      if db.registration_type == "rhn_satellite"
        db.update_attributes(
          :registration_type                      => nil,
          :registration_organization              => nil,
          :registration_server                    => nil,
          :registration_http_proxy_server         => nil,
          :update_repo_name                       => new_repos,
          :registration_organization_display_name => nil
        )

        Authentication.where(
          :resource_type => 'MiqDatabase',
          :resource_id   => db.id,
          :authtype      => [:registration_http_proxy, :registration]
        ).destroy_all
      end
    end
  end
end
