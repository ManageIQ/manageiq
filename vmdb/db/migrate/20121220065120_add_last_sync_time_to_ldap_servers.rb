class AddLastSyncTimeToLdapServers < ActiveRecord::Migration

  def up
    add_column    :ldap_servers, :last_user_sync,  :timestamp
    add_column    :ldap_servers, :last_group_sync, :timestamp
    change_column :ldap_users,   :whencreated,     :timestamp
    change_column :ldap_users,   :whenchanged,     :timestamp
  end

  def down
    remove_column :ldap_servers, :last_user_sync
    remove_column :ldap_servers, :last_group_sync
    change_column :ldap_users,   :whencreated,     :string
    change_column :ldap_users,   :whenchanged,     :string
  end

end
