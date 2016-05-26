class LdapGroup < ApplicationRecord
  belongs_to :ldap_domain
  # acts_as_miq_taggable
end
