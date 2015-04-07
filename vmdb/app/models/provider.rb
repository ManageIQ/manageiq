class Provider < ActiveRecord::Base
  include NewWithTypeStiMixin
  include AuthenticationMixin
  include ReportableMixin
  include AsyncDeleteMixin
  include EmsRefresh::Manager

  SUBCLASSES = %w(
    ProviderForeman
  )

  belongs_to :zone
  has_many :managers, :class_name => "ExtManagementSystem"

  def self.leaf_subclasses
    descendants.select { |d| d.subclasses.empty? }
  end

  def self.supported_subclasses
    subclasses.flat_map do |s|
      s.subclasses.empty? ? s : s.supported_subclasses
    end
  end

  def verify_ssl=(val)
    val = resolve_verify_ssl_value(val)
    super
  end

  def verify_ssl?
    verify_ssl != OpenSSL::SSL::VERIFY_NONE
  end

  def with_provider_connection(options = {})
    raise "no block given" unless block_given?
    $log.info("MIQ(#{self.class.name}##{__method__}) Connecting through #{self.class.name}: [#{name}]")
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

  private

  def resolve_verify_ssl_value(val)
    case val
    when true  then OpenSSL::SSL::VERIFY_PEER
    when false then OpenSSL::SSL::VERIFY_NONE
    else            val
    end
  end
end

# Preload any subclasses of this class, so that they will be part of the
#   conditions that are generated on queries against this class.
Provider::SUBCLASSES.each { |c| require_dependency Rails.root.join("app", "models", "#{c.underscore}.rb").to_s }
