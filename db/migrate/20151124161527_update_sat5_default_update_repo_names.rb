class UpdateSat5DefaultUpdateRepoNames < ActiveRecord::Migration
  class MiqDatabase < ActiveRecord::Base
    self.inheritance_column = :_type_disabled
  end

  REPO_NAME_HASH = {
    "rhel-x86_64-server-6-cf-me-3.2 rhel-x86_64-server-6-rhscl-1" => "rhel-x86_64-server-7-cf-me-4.0 rhel-x86_64-server-7-rhscl-1",
    ""                                                            => "rhel-x86_64-server-7-cf-me-4.0 rhel-x86_64-server-7-rhscl-1",
  }

  def up
    say_with_time("Updating update_repo_name") do
      update(REPO_NAME_HASH)
    end
  end

  def down
    say_with_time("Updating update_repo_name") do
      update(REPO_NAME_HASH.reject { |k, _v| k == "" }.invert)
    end
  end

  def update(hash)
    db = MiqDatabase.first
    return unless db
    new_repo = hash[db.update_repo_name]
    db.update_attributes(:update_repo_name => new_repo) if new_repo
  end
end
