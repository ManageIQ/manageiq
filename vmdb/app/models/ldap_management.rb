class LdapManagement < ActiveRecord::Base

  belongs_to :ldap_user
  belongs_to :manager, :class_name => "LdapUser"

end
