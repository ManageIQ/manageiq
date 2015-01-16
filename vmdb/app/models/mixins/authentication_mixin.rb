module AuthenticationMixin
  extend ActiveSupport::Concern

  included do
    has_many  :authentications, :as => :resource, :dependent => :destroy

    virtual_column :authentication_status,  :type => :string

    def self.authentication_check_schedule
      zone = MiqServer.my_server.zone
      assoc = self.name.tableize
      assocs = zone.respond_to?(assoc) ? zone.send(assoc) : []
      assocs.each { |ci| ci.authentication_check_types_queue }
    end
  end

  def authentication_userid_passwords
    authentications.select { |a| a.kind_of?(AuthUseridPassword) }
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

  def authentication_password_encrypted(type = nil)
    authentication_component(type, :password_encrypted)
  end

  def authentication_valid?(type = nil)
    !!authentication_component(type, :userid)
  end
  alias :has_credentials? :authentication_valid?

  def authentication_invalid?(type = nil)
    !authentication_valid?(type)
  end

  def authentication_status
    ordered_auths = authentication_userid_passwords.sort_by(&:status_severity)
    ordered_auths.last.try(:status) || "None"
  end

  def auth_user_pwd(type = nil)
    cred = authentication_best_fit(type)
    return nil if cred.nil? || cred.userid.blank?
    [cred.userid, cred.password]
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
      current[:new] = {:user => value[:userid], :password => value[:password]} unless value[:userid].blank?
      current[:old] = {:user => cred.userid, :password => cred.password} if cred

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
      cred = self.authentications.build(:name => "#{self.class.name} #{self.name}", :authtype => type.to_s, :type => "AuthUseridPassword") if cred.nil?
      cred.userid, cred.password = value[:userid], value[:password]

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
    authentication_userid_passwords.detect do |a|
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
      $log.warn("MIQ(#{self.class.name}.authentication_check_types_queue) Previous authentication_check_types for [#{self.name}] [#{self.id}] with opts: [#{options[:args].inspect}] is still running, skipping...#{help}") unless msg.nil?
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

  def authentication_check(*args)
    options = args.extract_options!
    types = args.first

    header = "MIQ(#{self.class.name}.authentication_check) type: [#{types.inspect}] for [#{self.id}] [#{self.name}]"
    auth = authentication_best_fit(types)

    unless self.authentication_valid?(types)
      $log.warn("#{header} Validation failed due to error: [#{Authentication::ERRORS[:incomplete]}]")
      auth.validation_failed(:incomplete) if auth
      return false
    end

    verify_args = self.is_a?(Host) ? [types, options] : types

    begin
      result = self.verify_credentials(*verify_args)
    rescue MiqException::MiqUnreachableError => err
      auth.validation_failed(:unreachable, err.to_s[0..200])
      $log.warn("#{header} Validation failed due to unreachable error: [#{err.to_s[0..500]}]")
      return false
    rescue MiqException::MiqInvalidCredentialsError => err
      result = false
    rescue => err
      auth.validation_failed(:error, err.to_s[0..200])
      $log.warn("#{header} Validation failed due to error: [#{err.to_s[0..500]}]")
      return false
    end

    if result
      auth.validation_successful
    else
      $log.warn("#{header} Validation failed due to error: [#{Authentication::ERRORS[:invalid]}]")
      auth.validation_failed(:invalid)
    end
    return result
  end

  private

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

  def authentication_types
    authentication_userid_passwords.collect(&:authentication_type).uniq
  end

  def authentication_delete(type)
    a = authentication_type(type)
    self.authentications.destroy(a) unless a.nil?
    return a
  end
end
