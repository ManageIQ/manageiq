class Provider < ApplicationRecord
  include NewWithTypeStiMixin
  include AuthenticationMixin
  include ReportableMixin
  include AsyncDeleteMixin
  include EmsRefresh::Manager
  include TenancyMixin

  belongs_to :tenant
  belongs_to :zone
  has_many :managers, :class_name => "ExtManagementSystem"

  has_many :endpoints, :through => :managers

  delegate :verify_ssl,
           :verify_ssl=,
           :verify_ssl?,
           :to => :default_endpoint

  virtual_column :verify_ssl, :type => :integer

  def self.leaf_subclasses
    descendants.select { |d| d.subclasses.empty? }
  end

  def self.supported_subclasses
    subclasses.flat_map do |s|
      s.subclasses.empty? ? s : s.supported_subclasses
    end
  end

  def self.short_token
    parent.name.demodulize
  end

  def image_name
    self.class.short_token.underscore
  end

  def default_endpoint
    default = endpoints.detect { |e| e.role == "default" }
    default || endpoints.build(:role => "default")
  end

  def with_provider_connection(options = {})
    raise "no block given" unless block_given?
    _log.info("Connecting through #{self.class.name}: [#{name}]")
    yield connect(options)
  end

  def my_zone
    zone.try(:name).presence || MiqServer.my_zone
  end
  alias_method :zone_name, :my_zone

  def refresh_ems
    raise "no #{ui_lookup(:table => "provider")} credentials defined" if self.missing_credentials?
    raise "#{ui_lookup(:table => "provider")} failed last authentication check" unless self.authentication_status_ok?
    managers.each { |manager| EmsRefresh.queue_refresh(manager) }
  end
end
