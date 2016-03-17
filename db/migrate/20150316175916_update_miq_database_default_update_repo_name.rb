class UpdateMiqDatabaseDefaultUpdateRepoName < ActiveRecord::Migration
  class MiqDatabase < ActiveRecord::Base; end

  REPO_NAME_HASH = {
    "rhel-x86_64-server-6-cf-me-3"                                => "rhel-x86_64-server-6-cf-me-3.2 rhel-x86_64-server-6-rhscl-1",
    "rhel-x86_64-server-6-cf-me-3.1 rhel-x86_64-server-6-rhscl-1" => "rhel-x86_64-server-6-cf-me-3.2 rhel-x86_64-server-6-rhscl-1",
    "cf-me-5.3-for-rhel-6-rpms rhel-server-rhscl-6-rpms"          => "cf-me-5.4-for-rhel-6-rpms rhel-server-rhscl-6-rpms",
  }

  def up
    say_with_time("Updating update_repo_name") do
      update(REPO_NAME_HASH)
    end
  end

  def down
    say_with_time("Updating update_repo_name") do
      update(REPO_NAME_HASH.invert)
    end
  end

  def update(hash)
    db = MiqDatabase.first
    if db
      new_repo = hash[db.update_repo_name]
      db.update_attributes(:update_repo_name => new_repo) if new_repo
    end
  end
end
