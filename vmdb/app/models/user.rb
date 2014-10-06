class User < ActiveRecord::Base
  include RelationshipMixin
  acts_as_miq_taggable
  include RegionMixin
  has_secure_password
  include CustomAttributeMixin
  include ActiveVmAggregationMixin
  include TimezoneMixin

  belongs_to :role, :class_name => "UiTaskSet", :foreign_key => :ui_task_set_id
  has_many   :miq_approvals, :as => :approver
  has_many   :miq_approval_stamps,  :class_name => "MiqApproval", :foreign_key => :stamper_id
  has_many   :miq_requests, :foreign_key => :requester_id
  has_many   :vms,           :foreign_key => :evm_owner_id
  has_many   :miq_templates, :foreign_key => :evm_owner_id
  has_many   :miq_widgets
  has_many   :miq_widget_contents, :dependent => :destroy
  has_many   :miq_widget_sets, :as => :owner, :dependent => :destroy
  has_many   :miq_reports, :dependent => :nullify
  belongs_to :current_group, :class_name => "MiqGroup"
  has_and_belongs_to_many :miq_groups
  scope      :admin, where(:userid => "admin")

  virtual_has_many :active_vms, :class_name => "VmOrTemplate"

  delegate   :miq_user_role, :to => :current_group, :allow_nil => true

  validates_presence_of   :name, :userid, :region
  validates_uniqueness_of :userid, :scope => :region
  validates_format_of     :email, :with => %r{\A([\w\.\-\+]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z}i,
    :allow_nil => true, :message => "must be a valid email address"
  validates_inclusion_of  :current_group, :in => proc { |u| u.miq_groups }, :allow_nil => true

  attr_accessor :ldaphost
  attr_accessor :basedn

  # use authenticate_bcrypt rather than .authenticate to avoid confusion
  # with the class method of the same name (User.authenticate)
  alias_method :authenticate_bcrypt, :authenticate
  serialize :filters

  include ReportableMixin

  @@ldaphost = ""
  @@basedn   = ""
  @@role_ns  = "/managed/user"
  @@role_cat = "role"

  @role_changed = false

  EVMROLE_SELF_SERVICE_ROLE_NAME         = "EvmRole-user_self_service"
  EVMROLE_LIMITED_SELF_SERVICE_ROLE_NAME = "EvmRole-user_limited_self_service"
  EVMROLE_SUPER_ADMIN_ROLE_NAME          = "EvmRole-super_administrator"
  EVMROLE_ADMIN_ROLE_NAME                = "EvmRole-administrator"

  DEFAULT_GROUP_MEMBERSHIPS_MAX_DEPTH    = 2

  serialize     :settings, Hash   #Implement settings column as a hash
  default_value_for(:settings) { Hash.new }

  def self.in_region
    where(:region => my_region_number)
  end

  def self.in_my_region
    where(:id => region_to_range(my_region_number))
  end

  def self.find_by_userid(userid)
    self.in_region.find(:first, :conditions => {:userid => userid})
  end

  def self.find_by_email(email)
    self.in_region.find(:first, :conditions => {:email  => email})
  end

  virtual_column :ldap_group, :type => :string, :uses => :current_group
  # FIXME: amazon_group too?
  virtual_column :miq_group_description, :type => :string, :uses => :current_group
  virtual_column :miq_user_role_name, :type => :string, :uses => {:current_group => :miq_user_role}

  def validate
    errors.add(:userid, "'system' is reserved for EVM internal operations") unless (self.userid =~ /^system$/i).nil?
  end

  before_validation :nil_email_field_if_blank
  before_validation :dummy_password_for_external_auth
  before_save :on_changed_admin_password
  before_destroy :destroy_subscribed_widget_sets

  def miq_group
    unless Rails.env.production?
      msg = "[DEPRECATION] miq_group accessor is deprecated.  Please use current_group instead.  At #{caller[0]}"
      $log.warn msg
      warn msg
    end

    current_group
  end

  def miq_group=(group)
    unless Rails.env.production?
      msg = "[DEPRECATION] miq_group= accessor is deprecated.  Please use current_group= instead.  At #{caller[0]}"
      $log.warn msg
      warn msg
    end

    self.current_group = group
  end

  def nil_email_field_if_blank
    self.email = nil if self.email.blank?
  end

  def dummy_password_for_external_auth
    if self.password.blank? && self.password_digest.blank? &&
        self.class.mode != "database"
      self.password = "dummy"
    end
  end

  def change_password(oldpwd, newpwd)
    mode = self.class.mode
    raise MiqException::MiqEVMLoginError, "password change not allowed when authentication mode is #{mode}" unless mode == "database"
    raise MiqException::MiqEVMLoginError, "old password does not match current password" unless User.authenticate(self.userid, oldpwd)

    self.password = newpwd
    self.save!
  end

  def get_filters
    filters = self.current_group.get_filters if self.current_group
    filters || {"managed" => [], "belongsto" => []}
  end

  def has_filters?
    !(self.get_managed_filters.blank? && self.get_belongsto_filters.blank?)
  end

  def get_managed_filters
    self.get_filters["managed"]
  end

  def get_belongsto_filters
    self.get_filters["belongsto"]
  end

  def self_service_user?
    return false if self.current_group.nil?
    self.current_group.self_service_group?
  end
  alias_method :self_service?, :self_service_user?

  def limited_self_service_user?
    return false if self.current_group.nil?
    self.current_group.limited_self_service_group?
  end
  alias_method :limited_self_service?, :limited_self_service_user?

  def super_admin_user?
    self.miq_user_role_name == EVMROLE_SUPER_ADMIN_ROLE_NAME
  end

  def admin_user?
    # Check for admin or super_admin
    role_name = self.miq_user_role_name
    role_name == EVMROLE_SUPER_ADMIN_ROLE_NAME || role_name == EVMROLE_ADMIN_ROLE_NAME
  end

  def ldap_group
    self.current_group ? self.current_group.description : nil
  end
  alias miq_group_description ldap_group

  def role_allows?(options={})
    return false if self.miq_user_role.nil?
    feature = MiqProductFeature.find_by_identifier(options[:identifier])
    identifiers = {:identifiers => [options[:identifier]]}
    feature.try(:hidden) ? miq_user_role.allows_any?(identifiers) : miq_user_role.allows?(options)
  end

  def role_allows_any?(options={})
    return false if self.miq_user_role.nil?
    self.miq_user_role.allows_any?(options)
  end

  def role_allows_all?(options={})
    return false if self.miq_user_role.nil?
    self.miq_user_role.allows_all?(options)
  end

  def miq_user_role_name
    self.miq_user_role.try(:name)
  end

  def self.mode
    VMDB::Config.new("vmdb").config[:authentication][:mode]
  end

  def self.ldaphost(host=nil)
    @@ldaphost = host unless host == nil
    return @@ldaphost
  end

  def self.basedn(dn=nil)
    @@basedn = dn unless dn == nil
    return @@basedn
  end

  def self.verify_ldap_credentials(username, password)
    ldap = MiqLdap.new
    fq_user = ldap.normalize(ldap.fqusername(username))
    raise MiqException::MiqEVMLoginError, "authentication failed" unless ldap.bind(fq_user, password)
  end

  def self.authenticate(username, password, request = nil, options = {})
    options = options.dup
    options[:require_user] ||= false
    fail_message = "Authentication failed"
    mode = self.mode

    begin
      user_or_taskid = if mode == "database" || username == "admin"
        self.authenticate_database(username, password)
      elsif mode == "ldap" || mode == "ldaps"
        self.authenticate_ldap(username, password)
      elsif mode == "amazon"
        self.authenticate_amazon(username, password)
      elsif mode == "httpd"
        authenticate_httpd(username, request)
      end

      raise MiqException::MiqEVMLoginError, fail_message if user_or_taskid.nil?
    rescue MiqException::MiqEVMLoginError => err
      $log.warn err.message
      raise
    rescue Exception => err
      $log.log_backtrace(err)
      raise MiqException::MiqEVMLoginError, err.message
    end

    if options[:require_user] && !user_or_taskid.kind_of?(self)
      task = MiqTask.wait_for_taskid(user_or_taskid, options)
      if task.nil? || MiqTask.status_error?(task.status) || MiqTask.status_timeout?(task.status)
        raise MiqException::MiqEVMLoginError, fail_message
      end
      user_or_taskid = find_by_userid(task.userid)
    end

    if user_or_taskid.kind_of?(self)
      user_or_taskid.lastlogon = Time.now.utc
      user_or_taskid.save!
    end
    return user_or_taskid
  end

  def self.authenticate_database(username, password)
    audit = {:event => "authenticate_database", :message => "Authentication failed for user #{username}", :userid => username}
    user = self.find_by_userid(username)

    if user.nil? || !(user.authenticate_bcrypt(password))
      AuditEvent.failure(audit)
      return nil
    end
    AuditEvent.success(audit.merge(:message => "Authentication successful for user #{username}"))

    return user
  end

  def self.authenticate_amazon(username, password)
    auth = VMDB::Config.new("vmdb").config[:authentication]
    audit = {:event => "authenticate_amazon", :userid => username}
    if password.blank?
      AuditEvent.failure(audit.merge(:message => "Authentication failed for user #{username}"))
      return nil
    end

    amazon_auth = AmazonAuth.new
    if amazon_auth.iam_authenticate(username, password)
      AuditEvent.success(audit.merge(:message => "User #{username} successfully validated as Amazon IAM user"))

      if auth[:amazon_role] == true
        user = self.authorize_amazon_queue(username)
      else
        # If role_mode == database we will only use amazon for authentication. Also, the user must exist in our database
        # otherwise we will fail authentication
        user = self.find_by_userid(username)
        unless user
          AuditEvent.failure(audit.merge(:message => "User #{username} authenticated but not defined in EVM"))
          raise MiqException::MiqEVMLoginError, "User authenticated but not defined in EVM, please contact your EVM administrator"
        end
        return nil unless user
      end

      AuditEvent.success(audit.merge(:message => "Authentication successful for user #{username}"))
      return user
    else
      AuditEvent.failure(audit.merge(:message => "Authentication failed for userid #{username}"))
      return nil
    end

    return user
  end

  def self.authorize_amazon_queue(username)
    task = MiqTask.create(:name => "Amazon IAM User Authorization of '#{username}'", :userid => username)
    unless MiqEnvironment::Process.is_ui_worker_via_command_line?
      cb = {:class_name => task.class.name, :instance_id => task.id, :method_name => :queue_callback_on_exceptions, :args => ['Finished']}
      MiqQueue.put(
        :queue_name   => "generic",
        :class_name   => self.to_s,
        :method_name  => "authorize_amazon",
        :args         => [task.id, username],
        :server_guid  => MiqServer.my_guid,
        :priority     => MiqQueue::HIGH_PRIORITY,
        :miq_callback => cb
      )
    else
      self.authorize_amazon(task.id, username)
    end

    return task.id
  end

  def self.authorize_amazon(taskid, username)
    log_prefix = "MIQ(User.authorize_amazon):"
    audit = {:event => "authorize_amazon", :userid => username}

    task = MiqTask.find_by_id(taskid)
    if task.nil?
      message = "#{log_prefix} Unable to find task with id: [#{taskid}]"
      $log.error(message)
      raise message
    end
    task.update_status("Active", "Ok", "Authorizing")

    begin
      auth = VMDB::Config.new("vmdb").config[:authentication]
      # Amazon IAM will be used for authentication and role assignment
      $log.info("#{log_prefix} AWS key: [#{auth[:amazon_key]}]")
      amazon_auth = AmazonAuth.new(:auth=>auth)
      $log.info("#{log_prefix}  User: [#{username}]")
      amazon_user = amazon_auth.iam_user(username)
      $log.debug("#{log_prefix} User obj from Amazon: #{amazon_user.inspect}")
      unless amazon_user
        msg = "Authentication failed for userid #{username}, unable to find IAM user object in Amazon"
        $log.warn("#{log_prefix}: #{msg}")
        AuditEvent.failure(audit.merge(:message => msg))
        task.error(msg)
        task.state_finished
        return nil
      end

      matching_groups = match_groups(amazon_auth.get_memberships(amazon_user))
      user   = self.find_by_userid(username) || self.new(:userid => username)
      user.update_attrs_from_iam(amazon_auth, amazon_user, username)
      user.save_successful_logon(matching_groups, audit, task)
    rescue Exception => err
      $log.log_backtrace(err)
      task.error(err.message)
      AuditEvent.failure(audit.merge(:message=> err.message))
      task.state_finished
      raise
    end
  end

  def self.authenticate_ldap(username, password)
    auth = VMDB::Config.new("vmdb").config[:authentication]
    audit = {:event => "authenticate_ldap", :userid => username}
    if password.blank?
      AuditEvent.failure(audit.merge(:message => "Authentication failed for user #{username}"))
      return nil
    end

    ldap = MiqLdap.new
    fq_user = ldap.normalize(ldap.fqusername(username))

    if ldap.bind(fq_user, password)
      AuditEvent.success(audit.merge(:message => "User #{fq_user} successfully binded to LDAP directory"))

      if auth[:ldap_role] == true
        user = self.authorize_ldap_queue(fq_user)
      else
        # If role_mode == database we will only use ldap for authentication. Also, the user must exist in our database
        # otherwise we will fail authentication
        user = self.find_by_userid(fq_user)

        default_group = MiqGroup.where(:description => auth[:default_group_for_users]).first if auth[:default_group_for_users]
        if user.nil? && default_group
          # when default group for ldap users is enabled, create the user
          user = new
          lobj = ldap.get_user_object(fq_user)
          user.update_attrs_from_ldap(ldap, lobj)
          user.save_successful_logon([default_group], audit)
          $log.info("MIQ(User.authenticate_ldap): Created User: [#{user.userid}]")
        end

        unless user
          AuditEvent.failure(audit.merge(:message => "User #{fq_user} authenticated but not defined in EVM"))
          raise MiqException::MiqEVMLoginError, "User authenticated but not defined in EVM, please contact your EVM administrator"
        end
      end

      AuditEvent.success(audit.merge(:message => "Authentication successful for user #{fq_user}"))
      return user
    else
      AuditEvent.failure(audit.merge(:message => "Authentication failed for userid #{fq_user}"))
      return nil
    end
  end

  def self.authorize_ldap_queue(fq_user)
    task = MiqTask.create(:name => "LDAP User Authorization of '#{fq_user}'", :userid => fq_user)
    unless MiqEnvironment::Process.is_ui_worker_via_command_line?
      cb = {:class_name => task.class.name, :instance_id => task.id, :method_name => :queue_callback_on_exceptions, :args => ['Finished']}
      MiqQueue.put(
        :queue_name   => "generic",
        :class_name   => self.to_s,
        :method_name  => "authorize_ldap",
        :args         => [task.id, fq_user],
        :server_guid  => MiqServer.my_guid,
        :priority     => MiqQueue::HIGH_PRIORITY,
        :miq_callback => cb
      )
    else
      self.authorize_ldap(task.id, fq_user)
    end

    return task.id
  end

  def self.authorize_ldap(taskid, fq_user)
    log_prefix = "MIQ(User.authorize_ldap):"
    audit = {:event => "authorize_ldap", :userid => fq_user}

    task = MiqTask.find_by_id(taskid)
    if task.nil?
      message = "#{log_prefix} Unable to find task with id: [#{taskid}]"
      $log.error(message)
      raise message
    end
    task.update_status("Active", "Ok", "Authorizing")

    begin
      auth = VMDB::Config.new("vmdb").config[:authentication]
      # Ldap will be used for authentication and role assignment
      $log.info("#{log_prefix} Bind DN: [#{auth[:bind_dn]}]")
      ldap = MiqLdap.new
      ldap.bind(auth[:bind_dn], auth[:bind_pwd]) #now bind with bind_dn so that we can do our searches.
      $log.info("#{log_prefix}  User FQDN: [#{fq_user}]")
      lobj = ldap.get_user_object(fq_user)
      $log.debug("#{log_prefix} User obj from LDAP: #{lobj.inspect}")
      unless lobj
        msg = "Authentication failed for userid #{fq_user}, unable to find user object in LDAP"
        $log.warn("#{log_prefix}: #{msg}")
        AuditEvent.failure(audit.merge(:message => msg))
        task.error(msg)
        task.state_finished
        return nil
      end

      matching_groups = match_groups(getUserMembership(ldap, lobj))
      userid = ldap.normalize(ldap.get_attr(lobj, :userprincipalname) || fq_user)
      user   = self.find_by_userid(userid) || self.new(:userid => userid)
      user.update_attrs_from_ldap(ldap, lobj)
      user.save_successful_logon(matching_groups, audit, task)
    rescue Exception => err
      $log.log_backtrace(err)
      task.error(err.message)
      AuditEvent.failure(audit.merge(:message=> err.message))
      task.state_finished
      raise
    end
  end

  def self.authenticate_httpd(username, request)
    audit = {:event => "authenticate_httpd", :userid => username}
    if request.nil?
      AuditEvent.failure(audit.merge(:message => "Authentication failed for user #{username}, request missing"))
      nil
    elsif request.headers['X_REMOTE_USER'].present?
      AuditEvent.success(audit.merge(:message => "User #{username} successfully validated by httpd"))

      if VMDB::Config.new("vmdb").config[:authentication][:httpd_role] == true
        user = authorize_httpd_queue(username, request)
      else
        # If role_mode == database we will only use httpd for authentication. Also, the user must exist in our database
        # otherwise we will fail authentication
        unless (user = find_by_userid(username))
          AuditEvent.failure(audit.merge(:message => "User #{username} authenticated but not defined in EVM"))
          raise MiqException::MiqEVMLoginError,
                "User authenticated but not defined in EVM, please contact your EVM administrator"
        end
      end

      AuditEvent.success(audit.merge(:message => "Authentication successful for user #{username}"))
      user
    else
      external_auth_error = request.headers['HTTP_X_EXTERNAL_AUTH_ERROR']
      AuditEvent.failure(audit.merge(:message => "Authentication failed for userid #{username} #{external_auth_error}"))
      nil
    end
  end

  def self.authorize_httpd_queue(username, request)
    task = MiqTask.create(:name => "External httpd User Authorization of '#{username}'", :userid => username)
    user_attrs = {:username  => username,
                  :fullname  => request.headers['X_REMOTE_USER_FULLNAME'],
                  :firstname => request.headers['X_REMOTE_USER_FIRSTNAME'],
                  :lastname  => request.headers['X_REMOTE_USER_LASTNAME'],
                  :email     => request.headers['X_REMOTE_USER_EMAIL']}
    membership_list = (request.headers['X_REMOTE_USER_GROUPS'] || '').split(":")

    if !MiqEnvironment::Process.is_ui_worker_via_command_line?
      authorize_httpd(task.id, username, user_attrs, membership_list)
    else
      MiqQueue.put(
        :queue_name   => "generic",
        :class_name   => to_s,
        :method_name  => "authorize_httpd",
        :args         => [task.id, username, user_attrs, membership_list],
        :server_guid  => MiqServer.my_guid,
        :priority     => MiqQueue::HIGH_PRIORITY,
        :miq_callback => {
          :class_name  => task.class.name,
          :instance_id => task.id,
          :method_name => :queue_callback_on_exceptions,
          :args        => ['Finished']
        })
    end

    task.id
  end

  def self.authorize_httpd(taskid, username, user_attrs, membership_list)
    log_prefix = "MIQ(User.authorize_httpd):"
    audit = {:event => "authorize_httpd", :userid => username}

    task = MiqTask.find_by_id(taskid)
    if task.nil?
      message = "#{log_prefix} Unable to find task with id: [#{taskid}]"
      $log.error(message)
      raise message
    end
    task.update_status("Active", "Ok", "Authorizing")

    begin
      VMDB::Config.new("vmdb").config[:authentication]
      $log.info("#{log_prefix}  User: [#{username}]")

      matching_groups = match_groups(membership_list)
      user = find_by_userid(username) || new(:userid => username)
      user.update_attrs_from_httpd(user_attrs)
      user.save_successful_logon(matching_groups, audit, task)
    rescue => err
      $log.log_backtrace(err)
      task.error(err.message)
      AuditEvent.failure(audit.merge(:message => err.message))
      task.state_finished
      raise
    end
  end

  def self.authenticate_with_http_basic(username, password, request = nil, options = {})
    options[:require_user] ||= false
    user, username = find_by_principalname(username)
    result = nil
    begin
      result = user.nil? ? nil : User.authenticate(username, password, request, options)
    rescue MiqException::MiqEVMLoginError
    end
    AuditEvent.failure(:userid => username, :message => "Authentication failed for user #{username}") if result.nil?
    [!!result, username]
  end

  def self.find_by_principalname(username)
    unless (user = User.find_by_userid(username))
      if username.include?('\\')
        parts = username.split('\\')
        username = "#{parts.last}@#{parts.first}"
      elsif !username.include?('@') && MiqLdap.using_ldap?
        suffix = VMDB::Config.new("vmdb").config.fetch_path(:authentication, :user_suffix)
        username = "#{username}@#{suffix}"
      end
      user = User.find_by_userid(username)
    end
    [user, username]
  end

  def logoff
    self.lastlogoff = Time.now.utc
    self.save
    AuditEvent.success(:event => "logoff", :message => "User #{userid} has logged off", :userid => userid)
  end

  def get_expressions(db=nil)
    sql = ["((search_type=? and search_key is null) or (search_type=? and search_key is null) or (search_type=? and search_key=?))",
           'default', 'global', 'user', self.userid
    ]
    unless db.nil?
      sql[0] += "and db=?"
      sql << db.to_s
    end
    MiqSearch.get_expressions(sql)
  end

  def with_my_timezone(&block)
    self.with_a_timezone(self.get_timezone, &block)
  end

  def get_timezone
    self.settings.fetch_path(:display, :timezone) || self.class.server_timezone
  end

  def self.find_or_create_by_ldap_email(email)
    self.find_or_create_by_ldap_attr("mail", email)
  end

  def self.find_or_create_by_ldap_upn(upn)
    self.find_or_create_by_ldap_attr("userprincipalname", upn)
  end

  def self.find_or_create_by_ldap_attr(attr, value)
    user = find_by_userid(value)
    return user if user

    ldap = MiqLdap.new

    user = case attr
    when "mail"
      self.find_by_email(value)
    when "userprincipalname"
      value = ldap.fqusername(value)
      self.find_by_userid(value)
    else
      raise "Attribute '#{attr}' is not supported"
    end

    return user unless user.nil?

    auth = VMDB::Config.new("vmdb").config[:authentication]
    raise "Unable to auto-create user because LDAP authentication is not enabled"       unless auth[:mode] == "ldap" || auth[:mode] == "ldaps"
    raise "Unable to auto-create user because LDAP bind credentials are not configured" unless auth[:ldap_role] == true

    ldap.bind(auth[:bind_dn], auth[:bind_pwd]) #now bind with bind_dn so that we can do our searches.

    uobj = ldap.get_user_object(value, attr)
    raise "Unable to auto-create user because LDAP search returned no data for user with #{attr}: [#{value}]" if uobj.nil?

    matching_groups = match_groups(getUserMembership(ldap, uobj))
    raise "Unable to auto-create user because unable to match user's group membership to an EVM role" if matching_groups.empty?

    user = self.new
    user.update_attrs_from_ldap(ldap, uobj)
    user.miq_groups = matching_groups
    user.save

    $log.info("MIQ(User.find_or_create_by_ldap_attr): Created User: [#{user.userid}]")

    return user
  end

  def update_attrs_from_ldap(ldap, obj)
    self.userid     = ldap.normalize(ldap.get_attr(obj, :userprincipalname) || ldap.get_attr(obj, :dn))
    self.name       = ldap.get_attr(obj, :displayname)
    self.first_name = ldap.get_attr(obj, :givenname)
    self.last_name  = ldap.get_attr(obj, :sn)
    email           = ldap.get_attr(obj, :mail)
    self.email      = email unless email.blank?
  end

  def update_attrs_from_httpd(user_attrs)
    self.userid     = user_attrs[:username]
    self.name       = user_attrs[:fullname]
    self.first_name = user_attrs[:firstname]
    self.last_name  = user_attrs[:lastname]
    self.email      = user_attrs[:email] unless user_attrs[:email].blank?
  end

  def update_attrs_from_iam(amazon_auth, amazon_user, username)
    self.userid     = username
    self.name       = amazon_user.name
  end

  def save_successful_logon(matching_groups, audit = nil, task = nil)
    log_prefix = "MIQ(User#save_successful_logon) User: [#{userid}]"
    if matching_groups.empty?
      msg = "Authentication failed for userid #{userid}, unable to match user's group membership to an EVM role"
      AuditEvent.failure(audit.merge(:message => msg)) if audit
      if task
        $log.warn("#{log_prefix}: #{msg}")
        task.error(msg)
        task.state_finished
      end
      return nil
    end

    self.miq_groups = matching_groups
    self.lastlogon = Time.now.utc unless task.nil?
    save!
    if task
      $log.info("#{log_prefix}: Authorized User: [#{userid}]")
      task.userid = userid
      task.update_status("Finished", "Ok", "User authorized successfully")
    end
    self
  end

  def current_group=(group)
    log_prefix = "MIQ(User#current_group=) User: [#{userid}]"
    super

    if group
      self.filters = group.filters
      $log.info("#{log_prefix} Assigning Role: [#{group.miq_user_role_name}] from Group: [#{group.description}]")
    else
      self.filters = nil
      $log.info("#{log_prefix} Removing Role: [#{miq_user_role_name}] and Group: [#{miq_group_description}]")
    end
  end

  def miq_groups=(groups)
    super
    self.current_group = groups.first if current_group.nil? || !groups.include?(current_group)
  end

  def miq_group_ids
    miq_groups.collect(&:id)
  end

  def self.all_users_of_group(group)
    User.includes(:miq_groups).select { |u| u.miq_groups.include?(group) }
  end

  def all_groups
    miq_groups
  end

  def admin?
    self.userid == "admin"
  end

  def sync_admin_password(fd = nil)
    raise "User is not admin" unless admin?

    fd_provided = !!fd
    fd ||= File.open(File.join(Rails.root, "config/miq_pass"), 'w')
    fd.puts self.read_attribute(:password_digest)
  ensure
    fd.close unless fd_provided
  end

  def self.sync_admin_password(fd = nil)
    User.admin.first.sync_admin_password(fd)
  end

  def subscribed_widget_sets
    MiqWidgetSet.subscribed_for_user(self)
  end

  def group_ids_of_subscribed_widget_sets
    subscribed_widget_sets.pluck(:group_id).compact.uniq
  end

  def subscribed_widget_sets_for_group(group_id)
    subscribed_widget_sets.where(:group_id => group_id)
  end

  def destroy_subscribed_widget_sets
    subscribed_widget_sets.destroy_all
  end

  def destroy_widget_sets_for_group(group_id)
    subscribed_widget_sets_for_group(group_id).destroy_all
  end

  def destroy_orphaned_dashboards
    (group_ids_of_subscribed_widget_sets - miq_group_ids).each { |group_id| destroy_widget_sets_for_group(group_id) }
  end

  def valid_for_login?
    !!miq_user_role
  end

  protected

  def on_changed_admin_password
    if admin? && self.password_digest_changed?
      sync_admin_password

      # notify other servers in region, to call MiqUser#sync_admin_password
      MiqRegion.my_region.miq_servers.each do |s|
        next if s.guid == MiqServer.my_guid
        s.sync_admin_password_queue
      end
    end
  end

  private

  REQUIRED_LDAP_USER_PROXY_KEYS = [:basedn, :bind_dn, :bind_pwd, :ldaphost, :ldapport, :mode]
  def self.getUserProxyMembership(auth, sid)
    log_prefix = "MIQ(User.getUserProxyMembership)"

    authentication    = VMDB::Config.new("vmdb").config[:authentication]
    auth[:bind_dn]  ||= authentication[:bind_dn]
    auth[:bind_pwd] ||= authentication[:bind_pwd]
    auth[:ldapport] ||= authentication[:ldapport]
    auth[:mode]     ||= authentication[:mode]
    auth[:group_memberships_max_depth] ||= DEFAULT_GROUP_MEMBERSHIPS_MAX_DEPTH

    REQUIRED_LDAP_USER_PROXY_KEYS.each { |key| raise "Required key not specified: [#{key.to_s}]" unless auth.has_key?(key) }

    fsp_dn  = "cn=#{sid},CN=ForeignSecurityPrincipals,#{auth[:basedn]}"

    ldap_up = MiqLdap.new(:auth => { :ldaphost => auth[:ldaphost], :ldapport => auth[:ldapport], :mode => auth[:mode], :basedn => auth[:basedn] } )

    $log.info("#{log_prefix} Bind DN: [#{auth[:bind_dn]}], Host: [#{auth[:ldaphost]}], Port: [#{auth[:ldapport]}], Mode: [#{auth[:mode]}]")
    raise "Cannot Bind" unless ldap_up.bind(auth[:bind_dn], auth[:bind_pwd]) #now bind with bind_dn so that we can do our searches.
    $log.info("#{log_prefix} User SID: [#{sid}], FSP DN: [#{fsp_dn}]")
    user_proxy_object = ldap_up.search(:base => fsp_dn, :scope => :base).first
    raise "Unable to find user proxy object in LDAP" if user_proxy_object.nil?
    $log.debug("#{log_prefix} UserProxy obj from LDAP: #{user_proxy_object.inspect}")
    ldap_up.get_memberships(user_proxy_object, auth[:group_memberships_max_depth])
  end

  def self.getUserMembership(ldap, obj)
    authentication = VMDB::Config.new("vmdb").config[:authentication]
    authentication[:group_memberships_max_depth] ||= DEFAULT_GROUP_MEMBERSHIPS_MAX_DEPTH

    if authentication.has_key?(:user_proxies)       && !authentication[:user_proxies].blank?  &&
       authentication.has_key?(:get_direct_groups)  && authentication[:get_direct_groups] == false
      $log.info("MIQ(User.getUserMembership) Skipping getting group memberships directly assigned to user bacause it has been disabled in the configuration")
      groups = []
    else
      groups = ldap.get_memberships(obj, authentication[:group_memberships_max_depth])
    end

    if authentication.has_key?(:user_proxies)
      sid = MiqLdap.get_attr(obj, :objectsid)
      $log.warn("MIQ(User.getUserMembership) User Object has no objectSID") if sid.nil?

      authentication[:user_proxies].each do |auth|
        begin
          groups += self.getUserProxyMembership(auth, MiqLdap.sid_to_s(sid))
        rescue Exception => err
          $log.warn("MIQ(User.getUserMembership) #{err.message} (from User.getUserProxyMembership)")
        end
      end unless sid.nil?
    end

    groups.uniq
  end

  def self.match_groups(groups)
    log_prefix  = "MIQ(User#match_groups)"

    return [] if groups.empty?
    groups = groups.collect { |g| g.downcase }

    miq_groups  = MiqServer.my_server.miq_groups
    miq_groups  = MiqServer.my_server.zone.miq_groups if miq_groups.empty?
    miq_groups  = MiqGroup.find(:all, :conditions => {:resource_id => nil, :resource_type => nil}) if miq_groups.empty?
    miq_groups.sort!  { |a, b| a.sequence <=> b.sequence }
    groups.each       { |g| $log.debug("#{log_prefix} External Group: #{g}") }
    miq_groups.each   { |g| $log.debug("#{log_prefix} Internal Group: #{g.description.downcase}") }
    miq_groups.select { |g| groups.include?(g.description.downcase) }
  end

  def self.seed
    MiqRegion.my_region.lock do
      user = self.in_my_region.find_by_userid("admin")
      if user.nil?
        $log.info("MIQ(User.seed) Creating default admin user...")
        user = self.create(:userid => "admin", :name => "Administrator", :password => "smartvm")
        $log.info("MIQ(User.seed) Creating default admin user... Complete")
      end

      admin_group     = MiqGroup.in_my_region.find_by_description("EvmGroup-super_administrator")
      user.miq_groups = [admin_group] if admin_group
      user.save

    end
  end

  # Save the current user from the session object as a thread variable to allow lookup from other areas of the code
  def self.with_userid(userid)
    saved_user   = Thread.current[:user]
    saved_userid = Thread.current[:userid]
    self.current_userid = userid
    yield
  ensure
    Thread.current[:user]   = saved_user
    Thread.current[:userid] = saved_userid
  end

  def self.current_userid=(userid)
    Thread.current[:user]   = nil
    Thread.current[:userid] = userid
  end

  def self.current_userid
    Thread.current[:userid]
  end

  def self.current_user
    Thread.current[:user] ||= self.find_by_userid(self.current_userid)
  end

  def self.current_user_ldap_group
    self.current_user ? self.current_user.ldap_group : nil
  end

  def self.current_user_has_filters?
    if Thread.current[:user_has_filters].nil?
      Thread.current[:user_has_filters] =
        current_user.current_group.filters &&
        !(current_user.current_group.filters["managed"].blank? &&
          current_user.current_group.filters["belongs_to"].blank?)
    end
    return Thread.current[:user_has_filters]
  end
  #
end
