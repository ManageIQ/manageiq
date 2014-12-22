class CreateLdapServers < ActiveRecord::Migration
  def up
    create_table :ldap_servers do |t|
      t.string     :name
      t.string     :hostname
      t.string     :hostname_2
      t.string     :hostname_3
      t.string     :mode
      t.integer    :port
      t.string     :base_dn
      t.string     :user_type
      t.string     :user_suffix
      t.integer    :bind_timeout
      t.integer    :search_timeout
      t.integer    :group_membership_max_depth
      t.boolean    :get_direct_groups
      t.boolean    :follow_referrals
      t.belongs_to :ldap_server, :type => :bigint
      t.timestamps
    end
  end

  def down
    drop_table :ldap_servers
  end
end
