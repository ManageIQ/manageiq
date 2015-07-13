class AddLastSyncTimeToLdapServers < ActiveRecord::Migration

  def up
    add_column    :ldap_servers, :last_user_sync,  :timestamp
    add_column    :ldap_servers, :last_group_sync, :timestamp
    change_column :ldap_users,   :whencreated,     :timestamp, :cast_as => :timestamp
    change_column :ldap_users,   :whenchanged,     :timestamp, :cast_as => :timestamp
  end

  def down
    remove_column :ldap_servers, :last_user_sync
    remove_column :ldap_servers, :last_group_sync
    change_column :ldap_users,   :whencreated,     :string, :cast_as => :string
    change_column :ldap_users,   :whenchanged,     :string, :cast_as => :string
  end

end
