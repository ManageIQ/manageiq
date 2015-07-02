class Authentication < ActiveRecord::Base
  include NewWithTypeStiMixin
  def self.new(*args, &block)
    if self == Authentication
      AuthUseridPassword.new(*args, &block)
    else
      super
    end
  end

  include PasswordMixin
  encrypt_column :auth_key

  belongs_to :resource, :polymorphic => true

  before_save :set_credentials_changed_on
  after_save :after_authentication_changed

  # TODO: DELETE ME!!!!
  ERRORS = {
    :incomplete => "Incomplete credentials",
    :invalid => "Invalid credentials",
  }

  STATUS_SEVERITY = Hash.new(-1).merge(
    ""            => -1,
    "valid"       => 0,
    "none"        => 1,
    "incomplete"  => 1,
    "error"       => 2,
    "unreachable" => 2,
    "invalid"     => 3,
  ).freeze

  def status_severity
    STATUS_SEVERITY[status.to_s.downcase]
  end

  def authentication_type
    self.authtype.nil? ? :default : self.authtype.to_sym
  end

  # The various status types:
  #   valid, invalid
  #   incomplete  (???)
  #   unreachable (for all communications errors)
  #   error (for unpredictable errors)
  def validation_successful
    new_status = :valid
    _log.info("[#{self.resource_type}] [#{self.resource_id}], previously valid/invalid on: [#{self.last_valid_on}]/[#{self.last_invalid_on}], previous status: [#{self.status}]") if self.status != new_status.to_s
    self.update_attributes(:status => new_status.to_s.capitalize, :status_details => 'Ok', :last_valid_on => Time.now.utc)
    self.raise_event(new_status)
  end

  def validation_failed(status=:unreachable, message = nil )
    message ||= ERRORS[status]
    _log.warn("[#{self.resource_type}] [#{self.resource_id}], previously valid on: #{self.last_valid_on}, previous status: [#{self.status}]")
    self.update_attributes(:status => status.to_s.capitalize, :status_details => message.to_s, :last_invalid_on => Time.now.utc)
    self.raise_event(status, message)
  end

  def raise_event(status, message = nil)
    ci = self.resource
    return unless ci

    prefix = event_prefix
    return if prefix.blank?

    MiqEvent.raise_evm_event_queue(ci, "#{prefix}_auth_#{status}")
  end

  private

  def set_credentials_changed_on
    return unless @auth_changed
    self.credentials_changed_on = Time.now.utc
  end

  def after_authentication_changed
    return unless @auth_changed
    _log.info("[#{self.resource_type}] [#{self.resource_id}], previously valid on: [#{self.last_valid_on}]")

    self.raise_event(:changed)

    # Async validate the credentials
    self.resource.authentication_check_types_queue(self.authentication_type) if self.resource
    @auth_changed = false
  end

  def event_prefix
    return  case self.resource_type
    when "Host"                then "host"
    when "ExtManagementSystem" then "ems"
    end
  end
end
