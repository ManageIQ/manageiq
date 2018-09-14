class User < ApplicationRecord
  include RelationshipMixin
  acts_as_miq_taggable
  has_secure_password
  include CustomAttributeMixin
  include ActiveVmAggregationMixin
  include TimezoneMixin
  include CustomActionsMixin

  has_many   :miq_approvals, :as => :approver
  has_many   :miq_approval_stamps,  :class_name => "MiqApproval", :foreign_key => :stamper_id
  has_many   :miq_requests, :foreign_key => :requester_id
  has_many   :vms,           :foreign_key => :evm_owner_id
  has_many   :miq_templates, :foreign_key => :evm_owner_id
  has_many   :miq_widgets
  has_many   :miq_widget_contents, :dependent => :destroy
  has_many   :miq_widget_sets, :as => :owner, :dependent => :destroy
  has_many   :miq_reports, :dependent => :nullify
  has_many   :service_orders, :dependent => :nullify
  has_many   :owned_shares, :class_name => "Share"
  has_many   :notification_recipients, :dependent => :delete_all
  has_many   :notifications, :through => :notification_recipients
  has_many   :unseen_notification_recipients, -> { unseen }, :class_name => 'NotificationRecipient'
  has_many   :unseen_notifications, :through => :unseen_notification_recipients, :source => :notification
  has_many   :authentications, :foreign_key => :evm_owner_id, :dependent => :nullify, :inverse_of => :evm_owner
  belongs_to :current_group, :class_name => "MiqGroup"
  has_and_belongs_to_many :miq_groups
  scope      :superadmins, lambda {
    joins(:miq_groups => {:miq_user_role => :miq_product_features})
      .where(:miq_product_features => {:identifier => MiqProductFeature::SUPER_ADMIN_FEATURE })
  }

  virtual_has_many :active_vms, :class_name => "VmOrTemplate"

  delegate   :miq_user_role, :current_tenant, :get_filters, :has_filters?, :get_managed_filters, :get_belongsto_filters,
             :to => :current_group, :allow_nil => true
  delegate   :super_admin_user?, :request_admin_user?, :self_service?, :limited_self_service?, :report_admin_user?,
             :to => :miq_user_role, :allow_nil => true

  validates_presence_of   :name, :userid
  validates :userid, :unique_within_region => {:match_case => false}
  validates :email, :format => {:with => MoreCoreExtensions::StringFormats::RE_EMAIL,
                                :allow_nil => true, :message => "must be a valid email address"}
  validates_inclusion_of  :current_group, :in => proc { |u| u.miq_groups }, :allow_nil => true

  # use authenticate_bcrypt rather than .authenticate to avoid confusion
  # with the class method of the same name (User.authenticate)
  alias_method :authenticate_bcrypt, :authenticate

  serialize     :settings, Hash   # Implement settings column as a hash
  default_value_for(:settings) { Hash.new }

  scope :with_same_userid, ->(id) { where(:userid => User.where(:id => id).pluck(:userid)) }

  def self.with_roles_excluding(identifier)
    where.not(:id => User.unscope(:select).joins(:miq_groups => :miq_product_features)
                             .where(:miq_product_features => {:identifier => identifier})
                             .select(:id))
  end

  def self.scope_by_tenant?
    true
  end

  ACCESSIBLE_STRATEGY_WITHOUT_IDS = {:descendant_ids => :descendants, :ancestor_ids => :ancestors}.freeze

  def self.tenant_id_clause(user_or_group)
    strategy = Rbac.accessible_tenant_ids_strategy(self)
    tenant = user_or_group.try(:current_tenant)
    return [] if tenant.root?

    accessible_tenants = tenant.send(ACCESSIBLE_STRATEGY_WITHOUT_IDS[strategy])

    users_ids = accessible_tenants.collect(&:user_ids).flatten + tenant.user_ids

    return if users_ids.empty?

    {table_name => {:id => users_ids}}
  end

  def self.find_by_userid(userid)
    in_my_region.find_by(:userid => userid)
  end

  def self.find_by_userid!(userid)
    in_my_region.find_by!(:userid => userid)
  end

  def self.find_by_email(email)
    in_my_region.find_by(:email => email)
  end

  # find a user by lowercase email
  # often we have the most probably user object onhand. so use that if possible
  def self.find_by_lower_email(email, cache = [])
    email = email.downcase
    Array.wrap(cache).detect { |u| u.email.try(:downcase) == email } || find_by(['lower(email) = ?', email])
  end

  virtual_column :ldap_group, :type => :string, :uses => :current_group
  # FIXME: amazon_group too?
  virtual_column :miq_group_description, :type => :string, :uses => :current_group
  virtual_column :miq_user_role_name, :type => :string, :uses => {:current_group => :miq_user_role}

  def validate
    errors.add(:userid, "'system' is reserved for EVM internal operations") unless (userid =~ /^system$/i).nil?
  end

  before_validation :nil_email_field_if_blank
  before_validation :dummy_password_for_external_auth
  before_destroy :destroy_subscribed_widget_sets

  def current_group_by_description=(group_description)
    if group_description
      desired_group = miq_groups.detect { |g| g.description == group_description }
      desired_group ||= MiqGroup.in_region(region_id).find_by(:description => group_description) if super_admin_user?
      self.current_group = desired_group if desired_group
    end
  end

  def nil_email_field_if_blank
    self.email = nil if email.blank?
  end

  def dummy_password_for_external_auth
    if password.blank? && password_digest.blank? &&
       !self.class.authenticator(userid).uses_stored_password?
      self.password = "dummy"
    end
  end

  def change_password(oldpwd, newpwd)
    auth = self.class.authenticator(userid)
    unless auth.uses_stored_password?
      raise MiqException::MiqEVMLoginError,
            _("password change not allowed when authentication mode is %{name}") % {:name => auth.class.proper_name}
    end
    if auth.authenticate(userid, oldpwd)
      self.password = newpwd
      self.save!
    end
  end

  def ldap_group
    current_group.try(:description)
  end
  alias_method :miq_group_description, :ldap_group

  def role_allows?(options = {})
    Rbac.role_allows?(options.merge(:user => self))
  end

  def role_allows_any?(options = {})
    Rbac.role_allows?(options.merge(:user => self, :any => true))
  end

  def miq_user_role_name
    miq_user_role.try(:name)
  end

  def self.authenticator(username = nil)
    Authenticator.for(::Settings.authentication.to_hash, username)
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

  def self.authorize_user(userid)
    return if userid.blank? || admin?(userid)
    authenticator(userid).authorize_user(userid)
  end

  def logoff
    self.lastlogoff = Time.now.utc
    save
    AuditEvent.success(:event => "logoff", :message => "User #{userid} has logged off", :userid => userid)
  end

  def get_expressions(db = nil)
    sql = ["((search_type=? and search_key is null) or (search_type=? and search_key is null) or (search_type=? and search_key=?))",
           'default', 'global', 'user', userid
          ]
    unless db.nil?
      sql[0] += "and db=?"
      sql << db.to_s
    end
    MiqSearch.get_expressions(sql)
  end

  def with_my_timezone(&block)
    with_a_timezone(get_timezone, &block)
  end

  def get_timezone
    settings.fetch_path(:display, :timezone) || self.class.server_timezone
  end

  def miq_groups=(groups)
    super
    self.current_group = groups.first if current_group.nil? || !groups.include?(current_group)
  end

  def change_current_group
    user_groups = miq_group_ids
    user_groups.delete(current_group_id)
    raise _("The user's current group cannot be changed because the user does not belong to any other group") if user_groups.empty?
    self.current_group = MiqGroup.find_by(:id => user_groups.first)
    save!
  end

  def admin?
    self.class.admin?(userid)
  end

  def self.admin?(userid)
    userid == "admin"
  end

  def subscribed_widget_sets
    MiqWidgetSet.subscribed_for_user(self)
  end

  def destroy_subscribed_widget_sets
    subscribed_widget_sets.destroy_all
  end

  def accessible_vms
    if limited_self_service?
      vms
    elsif self_service?
      (vms + miq_groups.includes(:vms).collect(&:vms).flatten).uniq
    else
      Vm.all
    end
  end

  def self.super_admin
    in_my_region.find_by_userid("admin")
  end

  def self.current_tenant
    current_user.try(:current_tenant)
  end

  # Save the current user from the session object as a thread variable to allow lookup from other areas of the code
  def self.with_user(user, userid = nil)
    saved_user   = Thread.current[:user]
    saved_userid = Thread.current[:userid]
    self.current_user = user
    Thread.current[:userid] = userid if userid
    yield
  ensure
    Thread.current[:user]   = saved_user
    Thread.current[:userid] = saved_userid
  end

  def self.with_user_group(user, group, &block)
    return yield if user.nil?
    user = User.find(user) unless user.kind_of?(User)
    if group && group.kind_of?(MiqGroup)
      user.current_group = group
    elsif group != user.current_group_id
      group = MiqGroup.find_by(:id => group)
      user.current_group = group if group
    end
    User.with_user(user, &block)
  end

  def self.current_user=(user)
    Thread.current[:userid] = user.try(:userid)
    Thread.current[:user] = user
  end

  # avoid using this. pass current_user where possible
  def self.current_userid
    Thread.current[:userid]
  end

  def self.current_user
    Thread.current[:user] ||= find_by_userid(current_userid)
  end

  # parallel to MiqGroup.with_groups - only show users with these groups
  def self.with_groups(miq_group_ids)
    includes(:miq_groups).where(:miq_groups => {:id => miq_group_ids})
  end

  def self.missing_user_features(db_user)
    if !db_user
      "User"
    elsif !db_user.current_group
      "Group"
    elsif !db_user.current_group.miq_user_role
      "Role"
    end
  end

  def self.seed
    seed_data.each do |user_attributes|
      user_id = user_attributes[:userid]
      next if in_my_region.find_by_userid(user_id)
      log_attrs = user_attributes.slice(:name, :userid, :group)
      _log.info("Creating user with parameters #{log_attrs.inspect}")

      group_description = user_attributes.delete(:group)
      group = MiqGroup.in_my_region.find_by(:description => group_description)

      _log.info("Creating #{user_id} user...")
      user = create(user_attributes)
      user.miq_groups = [group] if group
      user.save
      _log.info("Creating #{user_id} user... Complete")
    end
  end

  def self.seed_file_name
    @seed_file_name ||= Rails.root.join("db", "fixtures", "#{table_name}.yml")
  end
  private_class_method :seed_file_name

  def self.seed_data
    File.exist?(seed_file_name) ? YAML.load_file(seed_file_name) : []
  end
  private_class_method :seed_data
end
