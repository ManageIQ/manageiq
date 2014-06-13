class AddVdiUserReltionshipToLdapUsers < ActiveRecord::Migration
  def up
    change_table :ldap_users do |t|
       t.belongs_to   :vdi_user
       t.string       :sam_account_name
       t.string       :upn
     end
  end

  def down
    change_table :ldap_users do |t|
      t.remove_belongs_to   :vdi_user
      t.remove              :sam_account_name
      t.remove              :upn
    end
  end
end
