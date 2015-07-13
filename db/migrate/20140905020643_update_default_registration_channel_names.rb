class UpdateDefaultRegistrationChannelNames < ActiveRecord::Migration
  class MiqDatabase < ActiveRecord::Base
    self.inheritance_column = :_type_disabled # disable STI
  end

  def up
    say_with_time("Updating Default Registration Channel Names for v5.3") do
      db = MiqDatabase.first
      if db.try(:update_repo_name) == "cf-me-5.2-for-rhel-6-rpms"
        db.update_attributes(:update_repo_name => "cf-me-5.3-for-rhel-6-rpms rhel-server-rhscl-6-rpms")
      end
    end
  end
end
