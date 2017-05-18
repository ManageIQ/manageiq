class DropMiqServerRhnMirror < ActiveRecord::Migration[5.0]
  class ServerRole < ActiveRecord::Base; end
  class AssignedServerRole < ActiveRecord::Base; end
  class SettingsChange < ActiveRecord::Base
    serialize :value
  end

  def up
    remove_column :miq_servers, :rhn_mirror

    say_with_time("Removing RHN Mirror role") do
      role = ServerRole.find_by(:name => "rhn_mirror")
      if role
        AssignedServerRole.delete_all(:server_role_id => role.id)
        role.delete
      end
    end

    say_with_time("Removing RHN Mirror role from currently configured servers") do
      changes = SettingsChange.where(:key => "/server/role")
      changes.each do |change|
        role_list = change.value.split(",")
        change.value = role_list.reject { |role| role == "rhn_mirror" }.join(",")
        change.save!
      end
    end
  end
end
