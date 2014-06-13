class CreateLdapUsersAndLdapGroups < ActiveRecord::Migration
  def up
    create_table :ldap_groups do |t|
      t.string     :dn
      t.string     :display_name
      t.string     :whencreated
      t.string     :whenchanged
      t.string     :mail
      t.belongs_to :ldap_server
      t.timestamps
    end

    create_table :ldap_users do |t|
      t.string     :dn
      t.string     :first_name
      t.string     :last_name
      t.string     :title
      t.string     :display_name
      t.string     :mail
      t.string     :address
      t.string     :city
      t.string     :state
      t.string     :zip
      t.string     :country
      t.string     :company
      t.string     :department
      t.string     :office
      t.string     :phone
      t.string     :phone_home
      t.string     :phone_mobile
      t.string     :fax
      t.string     :whencreated
      t.string     :whenchanged
      t.string     :sid

      t.belongs_to :ldap_server
      t.timestamps
    end

    create_table :ldap_managements do |t|    #, :id => false
      t.bigint :manager_id
      t.bigint :ldap_user_id
    end

  end

  def down
    drop_table :ldap_groups
    drop_table :ldap_users
    drop_table :ldap_managements
  end
end
