module AuthenticationMixin
  extend ActiveSupport::Concern

  AUTH_BASE_CLASS    = 'Authentication'
  AUTH_DEFAULT_CLASS = 'AuthUseridPassword'

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

  def has_authentication_type?(type, class_name=AUTH_DEFAULT_CLASS)
    authentication_types(class_name).include?(type)
  end

  def authentication_userid(type=nil, class_name=AUTH_DEFAULT_CLASS)
    authentication_component_or_nil(type, class_name, :userid)
  end

  def authentication_password(type=nil, class_name=AUTH_DEFAULT_CLASS)
    authentication_component_or_nil(type, class_name, :password)
  end

  def authentication_password_encrypted(type=nil, class_name=AUTH_DEFAULT_CLASS)
    authentication_component_or_nil(type, class_name, :password_encrypted)
  end

  def authentication_valid?(type=nil, class_name=AUTH_DEFAULT_CLASS)
    !!authentication_component_or_nil(type, class_name, :userid)
  end

  def authentication_invalid?(type=nil, class_name=AUTH_DEFAULT_CLASS)
    !self.authentication_valid?(type, class_name)
  end
  alias :has_credentials? :authentication_valid?

  def authentication_status(class_name=AUTH_DEFAULT_CLASS)
    worst = nil
    authentications_by_class(class_name).each do |a|
      next unless a.status
      worst ||= a.status
      worst = a.status if a.status_worse_than(worst)
    end

    # If we have no authentications, or all of them have no status (ie, never validated), return "None"
    worst ||= "None"
    return worst
  end

  def auth_user_pwd(type=nil, class_name=AUTH_DEFAULT_CLASS)
    cred = authentication_best_fit(type, class_name)
    return nil if cred.blank? || cred.userid.blank?
    [cred.userid, cred.password]
  end

  #
  # Only for AuthUseridPassword class authentications.
  #
  def update_authentication(data, options = {})
    return if data.blank?

    options.reverse_merge!({:save => true})

    @orig_credentials ||= self.auth_user_pwd(AUTH_DEFAULT_CLASS) || "none"

    # Invoke before callback
    self.before_update_authentication if self.respond_to?(:before_update_authentication) && options[:save]

    data.each_pair do |type, value|
      cred = self.authentication_type(type, AUTH_DEFAULT_CLASS)
      current = {:new=>nil, :old => nil}
      current[:new] = {:user=>value[:userid], :password=>value[:password]} unless value[:userid].blank?
      current[:old] = {:user=>cred.userid, :password=>cred.password} if cred

      # Raise an error if required fields are blank
      Array(options[:required]).each { |field| raise(ArgumentError, "#{field} is required") if value[field].blank? }

      # If old and new are the same then there is nothing to do
      next if current[:old] == current[:new]

      # Check if it is a delete
      if value[:userid].blank?
        current[:new] = nil
        next if options[:save] == false
        self.authentication_delete(type, AUTH_DEFAULT_CLASS)
        next
      end

      # Update or create
      cred = self.authentications.build(:name => "#{self.class.name} #{self.name}", :authtype => type.to_s, :type => AUTH_DEFAULT_CLASS) if cred.nil?
      cred.userid, cred.password = value[:userid], value[:password]

      cred.save if options[:save] && id
    end

    # Invoke callback
    self.after_update_authentication if self.respond_to?(:after_update_authentication) && options[:save]
    @orig_credentials = nil if options[:save]
  end

  #
  # Only for AUTH_DEFAULT_CLASS class authentications.
  #
  def credentials_changed?
    @orig_credentials ||= self.auth_user_pwd() || "none"
    new_credentials = self.auth_user_pwd() || "none"
    @orig_credentials != new_credentials
  end

  def authentication_best_fit(type=nil, class_name=AUTH_DEFAULT_CLASS)
    # Look for the supplied type and if that is not found return the default credentials
    cred = authentication_type(type, class_name)
    cred = authentication_default(class_name) if cred.blank?
    return nil if cred.blank?
    return cred
  end
  # protected :authentication_best_fit

  def authentication_default(class_name)
    cred = self.authentication_type(:default, class_name)
    return nil if cred.blank?
    return cred
  end
  # protected :authentication_default

  def authentication_type(type, class_name=AUTH_DEFAULT_CLASS)
    return nil if type.nil?
    cred = authentications_by_class(class_name).detect do |a|
      a.authentication_type.to_s == type.to_s
    end
    return nil if cred.blank?
    return cred
  end

  def authentication_delete(type, class_name)
    a = authentication_type(type, class_name)
    self.authentications.destroy(a) unless a.nil?
    return a
  end
  # protected :authentication_delete

  #
  # Only for AUTH_DEFAULT_CLASS class authentications.
  #
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

  #
  # Only for AUTH_DEFAULT_CLASS class authentications.
  #
  def authentication_check_types(*args)
    options = args.extract_options!
    types = args.first

    # Let the individual classes determine what authentication(s) need to be checked
    types = self.authentications_to_validate if self.respond_to?(:authentications_to_validate) && types.nil?
    types = [nil] if types.blank?
    types.to_miq_a.each { |t| self.authentication_check(t, options)}
  end

  #
  # Only for AUTH_DEFAULT_CLASS class authentications.
  #
  def authentication_check(*args)
    options = args.extract_options!
    types = args.first

    header = "MIQ(#{self.class.name}.authentication_check) type: [#{types.inspect}] for [#{self.id}] [#{self.name}]"
    auth = self.authentication_best_fit(types, AUTH_DEFAULT_CLASS)

    unless self.authentication_valid?(types, AUTH_DEFAULT_CLASS)
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

  # The list of extensions available for this object by authentication type.
  #
  # Only extensions that have been already provided a value are saved.  This
  # list includes the extensions that have values, as well as any extensions
  # that can be provided for this authentication's type.
  #
  # The returned extensions are a list of AuthenticationExtension objects.
  # Those that have been saved have an id.  While extensions that have never
  # been provided have a +nil+ id.
  def authentication_extensions(authtype)
    authtype = authtype.to_sym
    auth = self.authentication_type(authtype.to_sym)
    extensions = auth ? auth.extensions : []

    authext_map = extensions.each_with_object({}) { |e,h| h[e.authentication_extension_type.id] = e }
    ext_types = AuthenticationExtensionType.where(:authtype => authtype)
    ext_types.map { |type| authext_map[type.id] || AuthenticationExtension.new({:authentication => auth, :authentication_extension_type => type}) }
  end

  private

  def authentication_component_or_nil(type, class_name, method)
    cred = authentication_best_fit(type, class_name)
    return nil if cred.blank?

    value = cred.public_send(method)
    return value.blank? ? nil : value
  end

  def authentications_by_class(class_name)
    return authentications if class_name.nil? || class_name == AUTH_BASE_CLASS
    klass = class_name.constantize
    authentications.select { |a| a.kind_of?(klass) }
  end

  def authentication_types(class_name)
    authentications_by_class(class_name).collect {|a| a.authentication_type}.uniq
  end
end
