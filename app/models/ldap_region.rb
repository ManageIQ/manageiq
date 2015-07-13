class LdapRegion < ActiveRecord::Base
  include ReportableMixin

  validates_presence_of   :name
  validates_uniqueness_of :name

  belongs_to :zone

  has_many   :ldap_domains

  # acts_as_miq_taggable

  # include ReportableMixin

  def is_valid?
    self.ldap_domains.any?(&:is_valid?)
  end

  def self.valid_regions
    all.find_all(&:is_valid?)
  end

  def valid_domains
    ldap_domains.find_all(&:is_valid?)
  end

  def user_search(options)
    results = {}
    ldap_domains.each do |domain|
      next unless domain.is_valid?
      begin
        users = domain.user_search(options)
        results.merge!(users)
      rescue => err
        _log.error "Error during user search on domain <#{domain.id}:#{domain.name}>.  Msg:<#{err}>"
      end
    end
    results
  end

end
