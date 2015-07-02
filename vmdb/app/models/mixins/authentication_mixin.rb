module AuthenticationMixin
  extend ActiveSupport::Concern

  included do
    has_many  :authentications, :as => :resource, :dependent => :destroy

    virtual_column :authentication_status,  :type => :string

    def self.authentication_check_schedule
      zone = MiqServer.my_server.zone
      assoc = self.name.tableize
      assocs = zone.respond_to?(assoc) ? zone.send(assoc) : []
      assocs.each(&:authentication_check_types_queue)
    end
  end

  def supported_auth_attributes
    %w(userid password)
  end

  def authentication_userid_passwords
    authentications.select { |a| a.kind_of?(AuthUseridPassword) }
  end

  def authentication_key_pairs
    authentications.select { |a| a.kind_of?(AuthKeyPairOpenstackInfra) }
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

  def authentication_password_encrypted(type = nil)
    authentication_component(type, :password_encrypted)
  end

  def required_credential_fields(_type)
    [:userid]
  end

  def has_credentials?(type = nil)
    required_credential_fields(type).all? { |field| authentication_component(type, field) }
  end

  def missing_credentials?(type = nil)
    # TODO(lsmola) re-factor, make keypairs part of best_with, but containing also delegation to parents
    !has_credentials?(type) && !auth_user_keypair(type)
  end

  def authentication_status
    ordered_auths = authentication_userid_passwords.sort_by(&:status_severity)
    ordered_auths.last.try(:status) || "None"
  end

  def authentication_status_ok?(type = nil)
    authentication_best_fit(type).try(:status) == "Valid"
  end

  def auth_user_pwd(type = nil)
    cred = authentication_best_fit(type)
    return nil if cred.nil? || cred.userid.blank?
    [cred.userid, cred.password]
  end

  def auth_user_keypair(type = nil)
    cred = authentication_best_fit(type)
    return nil if cred.nil? || cred.userid.blank?
    [cred.userid, cred.auth_key]
  end

  def update_authentication(data, options = {})
    return if data.blank?

    options.reverse_merge!({:save => true})

    @orig_credentials ||= self.auth_user_pwd || "none"

    # Invoke before callback
    self.before_update_authentication if self.respond_to?(:before_update_authentication) && options[:save]

    data.each_pair do |type, value|
      cred = self.authentication_type(type)
      current = {:new => nil, :old => nil}

      if value[:auth_key]
        # TODO(lsmola) figure out if there is a better way. Password field is replacing \n with \s, I need to replace
        # them back
        fixed_auth_key = value[:auth_key].gsub(/-----BEGIN\sRSA\sPRIVATE\sKEY-----/, '')
        fixed_auth_key = fixed_auth_key.gsub(/-----END\sRSA\sPRIVATE\sKEY-----/, '')
        fixed_auth_key = fixed_auth_key.gsub(/\s/, "\n")
        value[:auth_key] = '-----BEGIN RSA PRIVATE KEY-----' + fixed_auth_key + '-----END RSA PRIVATE KEY-----'
      end

      unless value[:userid].blank?
        current[:new] = {:user => value[:userid], :password => value[:password], :auth_key => value[:auth_key]}
      end
      current[:old] = {:user => cred.userid, :password => cred.password, :auth_key => cred.auth_key} if cred

      # Raise an error if required fields are blank
      Array(options[:required]).each { |field| raise(ArgumentError, "#{field} is required") if value[field].blank? }

      # If old and new are the same then there is nothing to do
      next if current[:old] == current[:new]

      # Check if it is a delete
      if value[:userid].blank?
        current[:new] = nil
        next if options[:save] == false
        authentication_delete(type)
        next
      end

      # Update or create
      if cred.nil?
        if self.kind_of?(EmsOpenstackInfra) && value[:auth_key]
          # TODO(lsmola) investigate why build throws an exception, that it needs to be subclass of AuthUseridPassword
          cred = AuthKeyPairOpenstackInfra.new(:name => "#{self.class.name} #{self.name}", :authtype => type.to_s,
                                               :resource_id => id, :resource_type => "ExtManagementSystem")
          self.authentications << cred
        else
          cred = self.authentications.build(:name => "#{self.class.name} #{self.name}", :authtype => type.to_s,
                                            :type => "AuthUseridPassword")
        end
      end
      cred.userid, cred.password, cred.auth_key = value[:userid], value[:password], value[:auth_key]

      cred.save if options[:save] && id
    end

    # Invoke callback
    self.after_update_authentication if self.respond_to?(:after_update_authentication) && options[:save]
    @orig_credentials = nil if options[:save]
  end

  def credentials_changed?
    @orig_credentials ||= self.auth_user_pwd || "none"
    new_credentials = self.auth_user_pwd || "none"
    @orig_credentials != new_credentials
  end

  def authentication_type(type)
    return nil if type.nil?
    available_authentications.detect do |a|
      a.authentication_type.to_s == type.to_s
    end
  end

  def authentication_check_types_queue(*args)
    options = args.extract_options!
    types = args.first
    role = self.authentication_check_role if self.respond_to?(:authentication_check_role)
    zone = self.my_zone if self.respond_to?(:my_zone)

    #FIXME: Via schedule, a message is created with args = [], so all authentications will be checked,
    # while an authentication change will create a message with args [:default] or whatever
    # authentication is changed, so you can end up with two messages for the same ci
    options = {
      :class_name  => self.class.base_class.name,
      :instance_id => self.id,
      :method_name => 'authentication_check_types',
      :args        => [types.to_miq_a, options]
    }

    options[:role] = role if role
    options[:zone] = zone if zone

    MiqQueue.put_unless_exists(options) do |msg|
      #TODO: Refactor the help in this and the ScheduleWorker#queue_work method into the merge method
      help = "Check for a running server"
      help << " in zone: [#{options[:zone]}]"   if options[:zone]
      help << " with role: [#{options[:role]}]" if options[:role]
      _log.warn("Previous authentication_check_types for [#{self.name}] [#{self.id}] with opts: [#{options[:args].inspect}] is still running, skipping...#{help}") unless msg.nil?
    end
  end

  def authentication_check_types(*args)
    options = args.extract_options!
    types = args.first

    # Let the individual classes determine what authentication(s) need to be checked
    types = self.authentications_to_validate if self.respond_to?(:authentications_to_validate) && types.nil?
    types = [nil] if types.blank?
    types.to_miq_a.each { |t| self.authentication_check(t, options)}
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
    type            = args.first
    status, details = authentication_check_no_validation(type, options)
    auth            = authentication_best_fit(type)

    if save
      status == :valid ? auth.validation_successful : auth.validation_failed(status, details)
    end

    return status == :valid, details
  end

  private

  def authentication_check_no_validation(type, options)
    header  = "type: [#{type.inspect}] for [#{self.id}] [#{self.name}]"
    verify_args = self.is_a?(Host) ? [type, options] : type

    status, details =
      if self.missing_credentials?(type)
        [:incomplete, "Missing credentials"]
      else
        begin
          verify_credentials(*verify_args) ? [:valid, ""] : [:invalid, "Unknown reason"]
        rescue MiqException::MiqUnreachableError => err
          [:unreachable, err]
        rescue MiqException::MiqInvalidCredentialsError => err
          [:invalid, err]
        rescue => err
          [:error, err]
        end
      end

    details &&= details.to_s.truncate(200)

    _log.warn("#{header} Validation failed: #{status}, #{details}") unless status == :valid
    return status, details
  end

  def authentication_best_fit(type = nil)
    # Look for the supplied type and if that is not found return the default credentials
    authentication_type(type) || authentication_type(:default)
  end

  def authentication_component(type, method)
    cred = authentication_best_fit(type)
    return nil if cred.nil?

    value = cred.public_send(method)
    return value.blank? ? nil : value
  end

  def available_authentications
    authentication_userid_passwords + authentication_key_pairs
  end

  def authentication_types
    available_authentications.collect(&:authentication_type).uniq
  end

  def authentication_delete(type)
    a = authentication_type(type)
    self.authentications.destroy(a) unless a.nil?
    return a
  end
end
