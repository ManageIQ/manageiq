class User < ActiveRecord::Base
  include RelationshipMixin
  acts_as_miq_taggable
  include RegionMixin
  has_secure_password
  include CustomAttributeMixin
  include ActiveVmAggregationMixin
  include TimezoneMixin

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
  scope      :admin, -> { where(:userid => "admin") }

  virtual_has_many :active_vms, :class_name => "VmOrTemplate"

  delegate   :miq_user_role, :to => :current_group, :allow_nil => true

  validates_presence_of   :name, :userid, :region
  validates_uniqueness_of :userid, :scope => :region
  validates_format_of     :email, :with => %r{\A([\w\.\-\+]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\z}i,
    :allow_nil => true, :message => "must be a valid email address"
  validates_inclusion_of  :current_group, :in => proc { |u| u.miq_groups }, :allow_nil => true

  # use authenticate_bcrypt rather than .authenticate to avoid confusion
  # with the class method of the same name (User.authenticate)
  alias_method :authenticate_bcrypt, :authenticate
  serialize :filters

  include ReportableMixin

  @@role_ns  = "/managed/user"
  @@role_cat = "role"

  @role_changed = false

  EVMROLE_SELF_SERVICE_ROLE_NAME         = "EvmRole-user_self_service"
  EVMROLE_LIMITED_SELF_SERVICE_ROLE_NAME = "EvmRole-user_limited_self_service"
  EVMROLE_SUPER_ADMIN_ROLE_NAME          = "EvmRole-super_administrator"
  EVMROLE_ADMIN_ROLE_NAME                = "EvmRole-administrator"

  serialize     :settings, Hash   #Implement settings column as a hash
  default_value_for(:settings) { Hash.new }

  def self.in_region
    where(:region => my_region_number)
  end

  def self.in_my_region
    where(:id => region_to_range(my_region_number))
  end

  def self.find_by_userid(userid)
    self.in_region.where(:userid => userid).first
  end

  def self.find_by_email(email)
    self.in_region.where(:email => email).first
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
        !self.class.authenticator(userid).uses_stored_password?
      self.password = "dummy"
    end
  end

  def change_password(oldpwd, newpwd)
    auth = self.class.authenticator(userid)
    raise MiqException::MiqEVMLoginError, "password change not allowed when authentication mode is #{auth.class.proper_name}" unless auth.uses_stored_password?
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
    current_group.try(:description)
  end
  alias miq_group_description ldap_group

  def role_allows?(options={})
    return false if self.miq_user_role.nil?
    feature = MiqProductFeature.find_by_identifier(options[:identifier])
    identifiers = {:identifiers => [options[:identifier]]}
    if feature.try(:hidden)
      parent_feature = MiqProductFeature.parent_for_feature(options[:identifier])
      # always return true for common features that are hidden and are under hidden parent
      parent_feature.try(:hidden) ? true : miq_user_role.allows_any?(identifiers)
    else
      miq_user_role.allows?(options)
    end
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

  def self.authenticator(username=nil)
    Authenticator.for(VMDB::Config.new("vmdb").config[:authentication], username)
  end

  def self.authenticate(username, password, request = nil, options = {})
    authenticator(username).authenticate(username, password, request, options)
  end

  def self.authenticate_with_http_basic(username, password, request = nil, options = {})
    authenticator(username).authenticate_with_http_basic(username, password, request, options)
  end

  def self.lookup_by_identity(username)
    authenticator(username).lookup_by_identity(username)
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

  def current_group=(group)
    log_prefix = "User: [#{userid}]"
    super

    if group
      self.filters = group.filters
      _log.info("#{log_prefix} Assigning Role: [#{group.miq_user_role_name}] from Group: [#{group.description}]")
    else
      self.filters = nil
      _log.info("#{log_prefix} Removing Role: [#{miq_user_role_name}] and Group: [#{miq_group_description}]")
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

  def accessible_vms
    if limited_self_service_user?
      vms
    elsif self_service_user?
      (vms + miq_groups.includes(:vms).collect(&:vms).flatten).uniq
    else
      Vm.all
    end
  end

  private

  def self.seed
    MiqRegion.my_region.lock do
      user = self.in_my_region.find_by_userid("admin")
      if user.nil?
        _log.info("Creating default admin user...")
        user = self.create(:userid => "admin", :name => "Administrator", :password => "smartvm")
        _log.info("Creating default admin user... Complete")
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
    saved_filters = Thread.current[:user_has_filters]
    self.current_userid = userid
    yield
  ensure
    Thread.current[:user]   = saved_user
    Thread.current[:userid] = saved_userid
    Thread.current[:user_has_filters] = saved_filters
  end

  def self.current_userid=(userid)
    Thread.current[:user]   = nil
    Thread.current[:user_has_filters] = nil
    Thread.current[:userid] = userid
  end

  def self.current_userid
    Thread.current[:userid]
  end

  def self.current_user
    Thread.current[:user] ||= self.find_by_userid(self.current_userid)
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
