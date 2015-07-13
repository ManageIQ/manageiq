class AddGetGroupsFromLdapLdapServers < ActiveRecord::Migration

  def change
    add_column  :ldap_servers, :get_user_groups,            :boolean
    add_column  :ldap_servers, :get_roles_from_home_forest, :boolean
  end

end
