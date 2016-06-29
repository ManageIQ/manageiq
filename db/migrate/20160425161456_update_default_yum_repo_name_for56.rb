class UpdateDefaultYumRepoNameFor56 < ActiveRecord::Migration[5.0]
  class MiqDatabase < ActiveRecord::Base; end

  REPO_NAME_HASH = {
    "cf-me-5.5-for-rhel-7-rpms rhel-server-rhscl-7-rpms" => "cf-me-5.6-for-rhel-7-rpms rhel-server-rhscl-7-rpms"
  }.freeze

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
