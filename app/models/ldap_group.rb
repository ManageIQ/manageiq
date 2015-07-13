class LdapGroup < ActiveRecord::Base

  belongs_to :ldap_domain

  # acts_as_miq_taggable

  # include ReportableMixin

end
