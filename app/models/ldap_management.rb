class LdapManagement < ApplicationRecord
  belongs_to :ldap_user
  belongs_to :manager, :class_name => "LdapUser"
end
