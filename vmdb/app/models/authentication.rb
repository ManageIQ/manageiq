class Authentication < ActiveRecord::Base
  include NewWithTypeStiMixin
  include PasswordMixin
  encrypt_column :auth_key

  belongs_to :resource, :polymorphic => true

  has_many :extensions, :class_name => "AuthenticationExtension"

  before_save :set_credentials_changed_on
  after_save :after_authentication_changed

  ERRORS = {
    :incomplete => "Incomplete credentials",
    :invalid => "Invalid credentials",
  }

  BASE_CLASS    = 'Authentication'
  DEFAULT_CLASS = 'AuthUseridPassword'

  module StatusSeverity
    VALID         = 0
    NONE          = 1
    INCOMPLETE    = 1
    ERROR         = 2
    UNREACHABLE   = 2
    INVALID       = 3
  end

  def self.new(*args, &block)
    if self == BASE_CLASS.constantize
      klass = DEFAULT_CLASS.constantize
      raise "#{klass.name} is not a subclass of #{self.name}" unless klass <= self
      klass.new(*args, &block)
    else
      super
    end
  end

  def status_worse_than(other_status)
    return false if other_status.to_s.capitalize == self.status
    current =  StatusSeverity.const_get(self.status.to_s.upcase)
    proposed = StatusSeverity.const_get(other_status.to_s.upcase)
    return current >= proposed
  end

  def authentication_type
    self.authtype.nil? ? :default : self.authtype.to_sym
  end

  def set_credentials_changed_on
    return unless @auth_changed
    self.credentials_changed_on = Time.now.utc
  end

  def after_authentication_changed
    return unless @auth_changed
    $log.info("MIQ(Authentication.after_authentication_changed) [#{self.resource_type}] [#{self.resource_id}], previously valid on: [#{self.last_valid_on}]")

    self.raise_event(:changed)

    # Async validate the credentials
    self.resource.authentication_check_types_queue(self.authentication_type) if self.resource
    @auth_changed = false
  end

  # The various status types:
  #   valid, invalid
  #   incomplete  (???)
  #   unreachable (for all communications errors)
  #   error (for unpredictable errors)
  def validation_successful
    new_status = :valid
    $log.info("MIQ(Authentication.validation_successful) [#{self.resource_type}] [#{self.resource_id}], previously valid/invalid on: [#{self.last_valid_on}]/[#{self.last_invalid_on}], previous status: [#{self.status}]") if self.status != new_status.to_s
    self.update_attributes(:status => new_status.to_s.capitalize, :status_details => 'Ok', :last_valid_on => Time.now.utc)
    self.raise_event(new_status)
  end

  def validation_failed(status=:unreachable, message = nil )
    message ||= ERRORS[status]
    $log.warn("MIQ(Authentication.validation_failed) [#{self.resource_type}] [#{self.resource_id}], previously valid on: #{self.last_valid_on}, previous status: [#{self.status}]")
    self.update_attributes(:status => status.to_s.capitalize, :status_details => message.to_s, :last_invalid_on => Time.now.utc)
    self.raise_event(status, message)
  end

  def raise_event(status, message = nil)
    ci = self.resource
    return unless ci

    prefix = self.event_prefix
    return if prefix.blank?

    MiqEvent.raise_evm_event_queue(ci, "#{prefix}_auth_#{status}")
  end

  def event_prefix
    return  case self.resource_type
    when "Host"                then "host"
    when "ExtManagementSystem" then "ems"
    end
  end
end
