class Provider < ApplicationRecord
  include NewWithTypeStiMixin
  include AuthenticationMixin
  include AsyncDeleteMixin
  include EmsRefresh::Manager
  include TenancyMixin

  belongs_to :tenant
  belongs_to :zone
  has_many :managers, :class_name => "ExtManagementSystem"

  has_many :endpoints, :through => :managers, :autosave => true

  delegate :verify_ssl,
           :verify_ssl?,
           :verify_ssl=,
           :url,
           :to => :default_endpoint

  virtual_column :verify_ssl,        :type => :integer
  virtual_column :security_protocol, :type => :string

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
    raise _("no block given") unless block_given?
    _log.info("Connecting through #{self.class.name}: [#{name}]")
    yield connect(options)
  end

  def my_zone
    zone.try(:name).presence || MiqServer.my_zone
  end
  alias_method :zone_name, :my_zone

  def refresh_ems
    if missing_credentials?
      raise _("no %{table} credentials defined") % {:table => ui_lookup(:table => "provider")}
    end
    unless authentication_status_ok?
      raise _("%{table} failed last authentication check") % {:table => ui_lookup(:table => "provider")}
    end
    managers.each { |manager| EmsRefresh.queue_refresh(manager) }
  end
end
