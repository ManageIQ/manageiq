class Authentication < ApplicationRecord
  acts_as_miq_taggable

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
  encrypt_column :password
  encrypt_column :service_account

  belongs_to :resource, :polymorphic => true

  has_many :authentication_configuration_script_bases,
           :dependent => :destroy
  has_many :configuration_script_bases,
           :through => :authentication_configuration_script_bases

  has_many :authentication_orchestration_stacks,
           :dependent => :destroy
  has_many :orchestration_stacks,
           :through => :authentication_orchestration_stacks

  has_many :configuration_script_sources

  before_save :set_credentials_changed_on
  after_save :after_authentication_changed

  serialize :options

  include OwnershipMixin
  include TenancyMixin

  belongs_to :tenant

  # TODO: DELETE ME!!!!
  ERRORS = {
    :incomplete => "Incomplete credentials",
    :invalid    => "Invalid credentials",
  }.freeze

  STATUS_SEVERITY = Hash.new(-1).merge(
    ""            => -1,
    "valid"       => 0,
    "none"        => 1,
    "incomplete"  => 1,
    "error"       => 2,
    "unreachable" => 2,
    "invalid"     => 3,
  ).freeze

  RETRYABLE_STATUS = %w(error unreachable).freeze

  CREDENTIAL_TYPES = {
    :external_credential_types         => 'ManageIQ::Providers::ExternalAutomationManager::Authentication',
    :embedded_ansible_credential_types => 'ManageIQ::Providers::EmbeddedAutomationManager::Authentication'
  }.freeze

  # FIXME: To address problem with url resolution when displayed as a quadicon,
  # but it's not *really* the db_name. Might be more proper to override `to_partial_path`
  def self.db_name
    "auth_key_pair_cloud"
  end

  def status_severity
    STATUS_SEVERITY[status.to_s.downcase]
  end

  def retryable_status?
    RETRYABLE_STATUS.include?(status.to_s.downcase)
  end

  def authentication_type
    authtype.nil? ? :default : authtype.to_sym
  end

  def available?
    password.present? || auth_key.present?
  end

  # The various status types:
  #   valid, invalid
  #   incomplete  (???)
  #   unreachable (for all communications errors)
  #   error (for unpredictable errors)
  def validation_successful
    new_status = :valid
    _log.info("[#{resource_type}] [#{resource_id}], previously valid/invalid on: [#{last_valid_on}]/[#{last_invalid_on}], previous status: [#{status}]") if status != new_status.to_s
    update_attributes(:status => new_status.to_s.capitalize, :status_details => 'Ok', :last_valid_on => Time.now.utc)
    raise_event(new_status)
  end

  def validation_failed(status = :unreachable, message = nil)
    message ||= ERRORS[status]
    _log.warn("[#{resource_type}] [#{resource_id}], previously valid on: #{last_valid_on}, previous status: [#{self.status}]")
    update_attributes(:status => status.to_s.capitalize, :status_details => message.to_s.truncate(200), :last_invalid_on => Time.now.utc)
    raise_event(status, message)
  end

  def raise_event(status, _message = nil)
    ci = resource
    return unless ci

    prefix = event_prefix
    return if prefix.blank?

    MiqEvent.raise_evm_event_queue(ci, "#{prefix}_auth_#{status}")
  end

  def assign_values(options)
    self.attributes = options
  end

  def self.build_credential_options
    CREDENTIAL_TYPES.each_with_object({}) do |(k, v), hash|
      hash[k] = v.constantize.descendants.each_with_object({}) do |klass, fields|
        fields[klass.name] = klass::API_OPTIONS if defined? klass::API_OPTIONS
      end
    end
  end

  def native_ref
    # to be overridden by individual provider/manager
    manager_ref
  end

  private

  def set_credentials_changed_on
    return unless @auth_changed
    self.credentials_changed_on = Time.now.utc
  end

  def after_authentication_changed
    return unless @auth_changed
    _log.info("[#{resource_type}] [#{resource_id}], previously valid on: [#{last_valid_on}]")

    raise_event(:changed)

    # Async validate the credentials
    resource.authentication_check_types_queue(authentication_type) if resource
    @auth_changed = false
  end

  def event_prefix
    case resource_type
    when "Host"                then "host"
    when "ExtManagementSystem" then "ems"
    end
  end
end
