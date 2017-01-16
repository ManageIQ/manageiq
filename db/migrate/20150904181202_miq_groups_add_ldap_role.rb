class MiqGroupsAddLdapRole < ActiveRecord::Migration
  class MiqUserRole < ActiveRecord::Base; end

  class MiqGroup < ActiveRecord::Base; end

  def up
    say_with_time "migrating old ldap groups" do
      MiqGroup.where(:group_type => "ldap").each do |g|
        role_id = MiqUserRole.find_by(:name => "EvmRole-#{g.description.split("-").last}").try(:id)
        g.update_attributes(
          :group_type       => "system",
          :miq_user_role_id => role_id
        )
      end
    end
  end
end
