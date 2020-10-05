module AuthenticationMixin
  extend ActiveSupport::Concern

  included do
    # There are some dirty, dirty Ruby/Rails reasons why this method needs to
    # exist like this, and I will try and explain:
    #
    # First, we need the extra +.where+ here because if this is used in a
    # nested SELECT statement (aka: virtual_delegate), the +resource_type+
    # check is dropped on the floor and not included in the subquery.  As a
    # result, it will just pickup the first record to match the
    # relationship_id column and that could be associated with any OTHER object
    # with an Authentication record.
    #
    # For example, you get back an Authentication record for an EMS record when
    # you are looking up one for a Host.
    #
    # Secondly, the reason this method exists, and is FIRST (prior to the
    # +has_one+ that uses it) is it needs to be defined prior to the
    # ActiveRecord::Relation method that calls it.  Also, it needs to be a
    # method so the proper local variable, +authentication_mixin_relation+, can
    # be defined with the class that the +resource_type+ needs to match and
    # remain in scope for the Proc below.  If it is a class variable or done in
    # other fashion, it will be overwritten whenever this module is included
    # elsewhere, or is called against ActiveRecord::Relation, and not the class
    # we are mixing into.
    #
    # Finally, the use of a prepared statement is also for some reason required
    # over the Hash syntax since otherwise the following is ERROR is produced
    # when doing a nested SELECT:
    #
    #     PG::ProtocolViolation: ERROR:  bind message supplies 0 parameters,
    #     but prepared statement "" requires 1 (ActiveRecord::StatementInvalid)
    #
    # FIXME:  If we handle this in `virtual_attributes`, then this can be
    # deleted and returned to the following proc on the has one:
    #
    #     has_one :authentication_status_severity_level,
    #             -> { order(Authentication::STATUS_SEVERITY_AREL.desc) }
    #             # ...
    #
    # But keep the test that was added ;)
    #
    def self.authentication_status_severity_level_filter
      # required to be done here so it is in scope of the Proc below
      authentication_mixin_relation = name

      proc do
        where('"authentications"."resource_type" = ?', authentication_mixin_relation)
          .order(Authentication::STATUS_SEVERITY_AREL.desc)
      end
    end

    has_many :authentications, :as => :resource, :dependent => :destroy, :autosave => true

    has_one  :authentication_status_severity_level,
             authentication_status_severity_level_filter,
             :as         => :resource,
             :inverse_of => :resource,
             :class_name => "Authentication"

    virtual_delegate :authentication_status,
                     :to        => "authentication_status_severity_level.status",
                     :default   => "None",
                     :type      => :string,
                     :allow_nil => true

    def self.authentication_check_schedule
      zone = MiqServer.my_server.zone
      assoc = name.tableize
      assocs = zone.respond_to?(assoc) ? zone.send(assoc) : []
      assocs.each { |a| a.authentication_check_types_queue(:attempt => 1) }
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
    authentications.select { |a| a.kind_of?(AuthPrivateKey) }
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
        current[:new] = {
          :user            => value[:userid],
          :password        => value[:password],
          :auth_key        => value[:auth_key],
          :service_account => value[:service_account].presence,
        }
      end
      if cred
        current[:old] = {
          :user            => cred.userid,
          :password        => cred.password,
          :auth_key        => cred.auth_key,
          :service_account => cred.service_account,
        }
      end

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
        # FIXME: after we completely move to DDF and revise the REST API for providers, this will probably be something to delete
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
      cred.userid          = value[:userid]
      cred.password        = value[:password]
      cred.auth_key        = value[:auth_key]
      cred.service_account = value[:service_account].presence

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
      :args        => [Array.wrap(types), method_options],
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

  # Change the password as a queued task and return the task id. The userid,
  # current password and new password are mandatory. The auth type is optional
  # and defaults to 'default'.
  #
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
      :queue_name  => queue_name_for_ems_operations,
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

  def assign_nested_endpoint(attributes)
    record = endpoints.where(:role => attributes['role']).first_or_initialize
    record.assign_attributes(attributes)
    record # `assign_attributes` always returns `nil`
  end

  def assign_nested_authentication(attributes)
    klass = authentication_class(attributes)
    record = authentications.where(:authtype => attributes['authtype']).first_or_initialize(:type => klass.to_s)
    record.assign_attributes(attributes.merge(:type => klass.to_s, :name => "#{self.class.name} #{name}"))
    record # `assign_attributes` always returns `nil`
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

  def authentication_class(attributes)
    attributes.symbolize_keys[:auth_key] ? AuthToken : AuthUseridPassword
  end
end
