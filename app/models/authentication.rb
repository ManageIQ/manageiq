class Authentication < ApplicationRecord
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

  before_save :set_credentials_changed_on
  after_save :after_authentication_changed

  # TODO: DELETE ME!!!!
  ERRORS = {
    :incomplete => "Incomplete credentials",
    :invalid    => "Invalid credentials",
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
    update_attributes(:status => status.to_s.capitalize, :status_details => message.to_s, :last_invalid_on => Time.now.utc)
    raise_event(status, message)
  end

  def raise_event(status, _message = nil)
    ci = resource
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


  def ansible_format(options = {})
    options.merge!({'name' => "example_name", 'login' => "true", 'challenge' => "true", 'kind' => ContainerDeployment::AUTHENTICATIONS_NAMES.key(authtype)})
    res = "openshift_master_identity_providers=[" + options.to_json + "]"
    if type.instance_of?(AuthenticationHtpasswd) && !htpassd_users.empty?
      res += "\nopenshift_master_htpasswd_users=#{htpassd_users.first.to_json}"
    end
    res
  end

  def ansible_config(options = {})
    options.merge!({'name' => "example_name", 'login' => "true", 'challenge' => "true", 'kind' => authtype})
  end

  def assign_values(options)
    options.each do |key, value|
      if Authentication.column_names.include?(key) && value
        if self[key].is_a? Array
          self[key] << value
        else
          self[key] = (!value.kind_of?(Array) && value.to_json.is_json?) ? value.to_json : value
        end
      end
    end
  end
end
