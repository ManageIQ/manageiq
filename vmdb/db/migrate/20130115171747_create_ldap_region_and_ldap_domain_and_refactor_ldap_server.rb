class CreateLdapRegionAndLdapDomainAndRefactorLdapServer < ActiveRecord::Migration
  def up
    rename_table  :ldap_servers, :ldap_domains

    remove_column :ldap_domains, :hostname
    remove_column :ldap_domains, :hostname_2
    remove_column :ldap_domains, :hostname_3
    remove_column :ldap_domains, :mode
    remove_column :ldap_domains, :port

    add_column    :ldap_domains, :ldap_region_id, :bigint
    add_index     :ldap_domains, :ldap_region_id

    rename_column :ldap_domains, :ldap_server_id, :ldap_domain_id
    rename_column :ldap_users,   :ldap_server_id, :ldap_domain_id
    rename_column :ldap_groups,  :ldap_server_id, :ldap_domain_id

    add_index     :ldap_users,   :ldap_domain_id
    add_index     :ldap_groups,  :ldap_domain_id

    create_table  :ldap_servers do |t|
      t.string    :hostname
      t.string    :mode
      t.integer   :port

      t.belongs_to :ldap_domain
      t.timestamps
    end
    add_index     :ldap_servers, :ldap_domain_id

    create_table  :ldap_regions do |t|
      t.string    :name
      t.string    :description

      t.belongs_to :zone
      t.timestamps
    end
    add_index     :ldap_regions, :zone_id
  end

  def down
    drop_table    :ldap_regions
    drop_table    :ldap_servers

    rename_column :ldap_groups,  :ldap_domain_id, :ldap_server_id
    rename_column :ldap_users,   :ldap_domain_id, :ldap_server_id
    rename_column :ldap_domains, :ldap_domain_id, :ldap_server_id

    remove_index  :ldap_domains, :ldap_region_id
    remove_column :ldap_domains, :ldap_region_id

    add_column    :ldap_domains, :port,       :integer
    add_column    :ldap_domains, :mode,       :string
    add_column    :ldap_domains, :hostname_3, :string
    add_column    :ldap_domains, :hostname_2, :string
    add_column    :ldap_domains, :hostname,   :string

    rename_table  :ldap_domains, :ldap_servers
  end
end
