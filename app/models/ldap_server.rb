class LdapServer < ApplicationRecord
  belongs_to :ldap_domain

  default_value_for :mode, "ldaps"
  default_value_for :port, 636

  attr_accessor :ldap

  acts_as_miq_taggable
  include AuthenticationMixin

  def name
    hostname
  end

  def connect
    ldap_domain.connect(self)
  end

  def connected?
    !!@ldap
  end

  def verify_credentials
    ldap_domain.verify_credentials(self)
  end

  def self.sync_data_from_timer(timestamp = Time.now)
    # Stub for now
    _log.info "time: #{timestamp}"
  end
end
