class LdapServer < ActiveRecord::Base

  belongs_to :ldap_domain

  default_value_for :mode, "ldaps"
  default_value_for :port, 636

  attr_accessor :ldap

  acts_as_miq_taggable

  include ReportableMixin
  include AuthenticationMixin

  def name
    self.hostname
  end

  def connect
    self.ldap_domain.connect(self)
  end

  def connected?
    @ldap ? true : false
  end

  def verify_credentials
    self.ldap_domain.verify_credentials(self)
  end

  def self.sync_data_from_timer(timestamp = Time.now)
    # Stub for now
    $log.info "MIQ(LDAP sync_data_from_timer): time: #{timestamp}"
  end

end
