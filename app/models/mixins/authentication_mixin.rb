module AuthenticationMixin
  extend ActiveSupport::Concern

  included do
    has_many :authentications, :as => :resource, :dependent => :destroy, :autosave => true

    has_one  :authentication_status_severity_level,
             -> { order(Authentication::STATUS_SEVERITY_AREL.desc) },
             :as         => :resource,
             :inverse_of => :resource,
             :class_name => "Authentication"

    virtual_delegate :authentication_status,
                     :to        => "authentication_status_severity_level.status",
                     :default   => "None",
                     :allow_nil => true

    def self.authentication_check_schedule
      zone = MiqServer.my_server.zone
      assoc = name.tableize
      assocs = zone.respond_to?(assoc) ? zone.send(assoc) : []
      assocs.each { |a| a.authentication_check_types_queue(:attempt => 1) }
    end

    def self.validate_credentials_task(args, user_id, zone)
      task_opts = {
        :action => "Validate EMS Provider Credentials",
        :userid => user_id
      }

      queue_opts = {
        :args        => [*args],
        :class_name  => self,
        :method_name => "raw_connect?",
        :queue_name  => "generic",
        :role        => "ems_operations",
        :zone        => zone
      }

      task_id = MiqTask.generic_action_with_callback(task_opts, queue_opts)
      task = MiqTask.wait_for_taskid(task_id, :timeout => 30)

      if task.nil?
        error_message = "Task Error"
      elsif MiqTask.status_error?(task.status) || MiqTask.status_timeout?(task.status)
        error_message = task.message
      end

      [error_message.blank?, error_message]
    end
  end

  def supported_auth_attributes
    %w(userid password)
  end

  def default_authentication_type
    :default
  end

  def authentication_userid_passwords
    authentications.select { |a| a.kind_of?(AuthUseridPassword) }
  end

  def authentication_tokens
    authentications.select { |a| a.kind_of?(AuthToken) }
  end

  def authentication_key_pairs
    authentications.select { |a| a.kind_of?(ManageIQ::Providers::Openstack::InfraManager::AuthKeyPair) }
  end

  def authentication_for_providers
    authentications.where.not(:authtype => nil)
  end

  def authentication_for_summary
    summary = []
    authentication_for_providers.each do |a|
      summary << {
        :authtype       => a.authtype,
        :status         => a.status,
        :status_details => a.status_details
      }
    end
    summary
  end

  def has_authentication_type?(type)
    authentication_types.include?(type)
  end

  def authentication_userid(type = nil)
    authentication_component(type, :userid)
  end

  def authentication_password(type = nil)
    authentication_component(type, :password)
  end

  def authentication_key(type = nil)
    authentication_component(type, :auth_key)
  end

  def authentication_token(type = nil)
    authentication_component(type, :auth_key)
  end

  def authentication_password_encrypted(type = nil)
    authentication_component(type, :password_encrypted)
  end

  def authentication_service_account(type = nil)
    authentication_component(type, :service_account)
  end

  def required_credential_fields(_type)
    [:userid]
  end

  def has_credentials?(type = nil)
    required_credential_fields(type).all? { |field| authentication_component(type, field) }
  end

  def missing_credentials?(type = nil)
    !has_credentials?(type)
  end

  def authentication_status_ok?(type = nil)
    authentication_best_fit(type).try(:status) == "Valid"
  end

  def auth_user_pwd(type = nil)
    cred = authentication_best_fit(type)
    return nil if cred.nil? || cred.userid.blank?
    [cred.userid, cred.password]
  end

  def auth_user_token(type = nil)
    cred = authentication_best_fit(type)
    return nil if cred.nil? || cred.userid.blank?
    [cred.userid, cred.auth_key]
  end

  def auth_user_keypair(type = nil)
    cred = authentication_best_fit(type)
    return nil if cred.nil? || cred.userid.blank?
    [cred.userid, cred.auth_key]
  end

  def update_authentication(data, options = {})
    return if data.blank?

    options.reverse_merge!(:save => true)

    @orig_credentials ||= auth_user_pwd || "none"

    # Invoke before callback
    before_update_authentication if self.respond_to?(:before_update_authentication) && options[:save]

    data.each_pair do |type, value|
      cred = authentication_type(type)
      current = {:new => nil, :old => nil}

      unless value.key?(:userid) && value[:userid].blank?
        current[:new] = {:user => value[:userid], :password => value[:password], :auth_key => value[:auth_key]}
      end
      current[:old] = {:user => cred.userid, :password => cred.password, :auth_key => cred.auth_key} if cred

      # Raise an error if required fields are blank
      Array(options[:required]).each { |field| raise(ArgumentError, "#{field} is required") if value[field].blank? }

      # If old and new are the same then there is nothing to do
      next if current[:old] == current[:new]

      # Check if it is a delete
      if value.key?(:userid) && value[:userid].blank?
        current[:new] = nil
        next if options[:save] == false
        authentication_delete(type)
        next
      end

      # Update or create
      if cred.nil?
        if self.kind_of?(ManageIQ::Providers::Openstack::InfraManager) && value[:auth_key]
          # TODO(lsmola) investigate why build throws an exception, that it needs to be subclass of AuthUseridPassword
          cred = ManageIQ::Providers::Openstack::InfraManager::AuthKeyPair.new(:name => "#{self.class.name} #{name}", :authtype => type.to_s,
                                               :resource_id => id, :resource_type => "ExtManagementSystem")
          authentications << cred
        elsif value[:auth_key]
          cred = AuthToken.new(:name => "#{self.class.name} #{name}", :authtype => type.to_s,
                                               :resource_id => id, :resource_type => "ExtManagementSystem")
          authentications << cred
        else
          cred = authentications.build(:name => "#{self.class.name} #{name}", :authtype => type.to_s,
                                            :type => "AuthUseridPassword")
        end
      end
      cred.userid = value[:userid]
      cred.password = value[:password]
      cred.auth_key = value[:auth_key]

      cred.save if options[:save] && id
    end

    # Invoke callback
    after_update_authentication if self.respond_to?(:after_update_authentication) && options[:save]
    @orig_credentials = nil if options[:save]
  end

  def credentials_changed?
    @orig_credentials ||= auth_user_pwd || "none"
    new_credentials = auth_user_pwd || "none"
    @orig_credentials != new_credentials
  end

  def authentication_type(type)
    return nil if type.nil?
    available_authentications.detect do |a|
      a.authentication_type.to_s == type.to_s
    end
  end

  def authentication_check_retry_deliver_on(attempt)
    # Existing callers who pass no attempt will have no delay.
    case attempt
    when nil, 0
      nil
    else
      Time.now.utc + exponential_delay(attempt - 1).minutes
    end
  end

  def exponential_delay(attempt)
    2**attempt
  end

  MAX_ATTEMPTS = 6
  # The default for the schedule is every 1.hour now.
  #   6 will gives us:
  #   A failure now and retries in 2, 4, 8, and 16 minutes, for a total of 30 minutes.
  #   We'll wait another 30 minutes, minus the time it takes to queue and perform the checks
  #   before the schedule fires again.
  def authentication_check_types_queue(*args)
    method_options = args.extract_options!
    types = args.first

    if method_options.fetch(:attempt, 0) < MAX_ATTEMPTS
      force = method_options.delete(:force) { false }
      message_attributes = authentication_check_attributes(types, method_options)
      put_authentication_check(message_attributes, force)
    end
  end

  def authentication_check_attributes(types, method_options)
    role = authentication_check_role if self.respond_to?(:authentication_check_role)
    zone = my_zone if self.respond_to?(:my_zone)

    # FIXME: Via schedule, a message is created with args = [], so all authentications will be checked,
    # while an authentication change will create a message with args [:default] or whatever
    # authentication is changed, so you can end up with two messages for the same ci
    options = {
      :class_name  => self.class.base_class.name,
      :instance_id => id,
      :method_name => 'authentication_check_types',
      :args        => [types.to_miq_a, method_options],
      :deliver_on  => authentication_check_retry_deliver_on(method_options[:attempt])
    }

    options[:role] = role if role
    options[:zone] = zone if zone
    options
  end

  def put_authentication_check(options, force)
    if force
      MiqQueue.put(options)
    else
      MiqQueue.create_with(options.slice(:args, :deliver_on)).put_unless_exists(options.except(:args, :deliver_on)) do |msg|
        # TODO: Refactor the help in this and the ScheduleWorker#queue_work method into the merge method
        help = "Check for a running server"
        help << " in zone: [#{options[:zone]}]"   if options[:zone]
        help << " with role: [#{options[:role]}]" if options[:role]
        _log.warn("Previous authentication_check_types for [#{name}] [#{id}] with opts: [#{options[:args].inspect}] is still running, skipping...#{help}") unless msg.nil?
        nil
      end
    end
  end

  def authentication_check_types(*args)
    options = args.extract_options!

    # Let the individual classes determine what authentication(s) need to be checked
    types = authentications_to_validate if respond_to?(:authentications_to_validate)
    types = args.first                  if types.blank?
    types = [nil]                       if types.blank?
    Array(types).each do |t|
      success = authentication_check(t, options.except(:attempt)).first
      retry_scheduled_authentication_check(t, options) unless success
    end
  end

  def retry_scheduled_authentication_check(auth_type, options)
    return unless options[:attempt]
    auth = authentication_best_fit(auth_type)

    if auth.try(:retryable_status?)
      options[:attempt] += 1

      # Force the authentication message to be queued
      authentication_check_types_queue(auth_type, options.merge(:force => true))
    end
  end

  # Returns [boolean check_result, string details]
  # check_result is true if and only if:
  #   * the system is reachable
  #   * AND we have the required authentication information
  #   * AND we successfully connected using the authentication
  #
  # details is a UI friendly message
  #
  # By default, the authentication's status is updated by the
  # validation_successful or validation_failed callbacks.
  #
  # An optional :save => false can be passed to bypass these callbacks.
  #
  # TODO: :valid, :incomplete, and friends shouldn't be littered in here and authentication
  def authentication_check(*args)
    options         = args.last.kind_of?(Hash) ? args.last : {}
    save            = options.fetch(:save, true)
    auth            = authentication_best_fit(args.first)
    type            = args.first || auth.try(:authtype)
    status, details = authentication_check_no_validation(type, options)

    if auth && save
      status == :valid ? auth.validation_successful : auth.validation_failed(status, details)
    end

    return status == :valid, details.truncate(20_000)
  end

  def default_authentication
    authentication_type(default_authentication_type)
  end

  # Changes the password of userId on provider client and database.
  #
  # @param [current_password] password currently used for connected userId in provider client
  # @param [new_password]     password that will replace the current one
  #
  # @return [Boolean] true if the routine is executed successfully
  #
  def change_password(current_password, new_password, auth_type = :default)
    unless supports?(:change_password)
      raise MiqException::Error, _("Change Password is not supported for %{class_description} provider") % {:class_description => self.class.description}
    end
    if change_password_params_valid?(current_password, new_password)
      raw_change_password(current_password, new_password)
      update_authentication(auth_type => {:userid => authentication_userid, :password => new_password})
    end

    true
  end

  def change_password_queue(userid, current_password, new_password, auth_type = :default)
    task_opts = {
      :action => "Changing the password for Physical Provider named '#{name}'",
      :userid => userid
    }

    queue_opts = {
      :class_name  => self.class.name,
      :instance_id => id,
      :method_name => 'change_password',
      :role        => 'ems_operations',
      :zone        => my_zone,
      :args        => [current_password, new_password, auth_type]
    }

    MiqTask.generic_action_with_callback(task_opts, queue_opts)
  end

  # This method must provide a way to change password on provider client.
  #
  # @param [_current_password]   password currently used for connected userId in provider client
  # @param [_new_password]       password that will replace the current one
  #
  # @return [Boolean]            true if the password was changed successfully
  #
  # @raise [MiqException::Error] containing the error message if was not changed successfully
  def raw_change_password(_current_password, _new_password)
    raise NotImplementedError, _("must be implemented in subclass.")
  end

  private

  def authentication_check_no_validation(type, options)
    header  = "type: [#{type.inspect}] for [#{id}] [#{name}]"
    status, details =
      if self.missing_credentials?(type)
        [:incomplete, "Missing credentials"]
      else
        begin
          verify_credentials(type, options) ? [:valid, ""] : [:invalid, "Unknown reason"]
        rescue MiqException::MiqUnreachableError => err
          [:unreachable, err]
        rescue MiqException::MiqInvalidCredentialsError, MiqException::MiqEVMLoginError => err
          [:invalid, err]
        rescue => err
          [:error, err]
        end
      end

    details &&= details.to_s

    _log.warn("#{header} Validation failed: #{status}, #{details.truncate(200)}") unless status == :valid
    return status, details
  end

  def authentication_best_fit(type = nil)
    # Look for the supplied type and if that is not found return the default credentials
    authentication_type(type) || authentication_type(default_authentication_type)
  end

  def authentication_component(type, method)
    cred = authentication_best_fit(type)
    return nil if cred.nil?

    value = cred.public_send(method)
    value.blank? ? nil : value
  end

  def available_authentications
    authentication_userid_passwords + authentication_key_pairs + authentication_tokens
  end

  def authentication_types
    available_authentications.collect(&:authentication_type).uniq
  end

  def authentication_delete(type)
    a = authentication_type(type)
    authentications.destroy(a) unless a.nil?
    a
  end

  #
  # Verifies if the change password params are valid
  #
  # @raise [MiqException::Error] if some required data is missing
  #
  # @return [Boolean] true if the params are fine
  #
  def change_password_params_valid?(current_password, new_password)
    return true unless current_password.blank? || new_password.blank?

    raise MiqException::Error, _("Please, fill the current_password and new_password fields.")
  end
end
