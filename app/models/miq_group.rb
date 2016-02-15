class MiqGroup < ApplicationRecord
  USER_GROUP   = "user"
  SYSTEM_GROUP = "system"
  TENANT_GROUP = "tenant"

  belongs_to :tenant
  belongs_to :miq_user_role
  belongs_to :resource, :polymorphic => true
  has_and_belongs_to_many :users
  has_many   :vms,         :dependent => :nullify
  has_many   :miq_templates, :dependent => :nullify
  has_many   :miq_reports, :dependent => :nullify
  has_many   :miq_report_results, :dependent => :nullify
  has_many   :miq_widget_contents, :dependent => :destroy
  has_many   :miq_widget_sets, :as => :owner, :dependent => :destroy

  virtual_column :miq_user_role_name, :type => :string,  :uses => :miq_user_role
  virtual_column :read_only,          :type => :boolean
  virtual_column :user_count,         :type => :integer

  delegate :self_service?, :limited_self_service?, :to => :miq_user_role, :allow_nil => true

  validates :description, :guid, :presence => true, :uniqueness => true
  validate :validate_default_tenant, :on => :update, :if => :tenant_id_changed?
  before_destroy :ensure_can_be_destroyed

  serialize :filters
  serialize :settings

  default_value_for :group_type, USER_GROUP
  default_value_for(:sequence) { next_sequence }

  acts_as_miq_taggable
  include ReportableMixin
  include UuidMixin
  include CustomAttributeMixin
  include ActiveVmAggregationMixin
  include TimezoneMixin
  include TenancyMixin

  FIXTURE_DIR = File.join(Rails.root, "db/fixtures")

  alias_method :current_tenant, :tenant

  def name
    description
  end

  def all_users
    User.all_users_of_group(self)
  end

  def self.allows?(_group, _options = {})
    # group: Id || Instance
    # :identifier => Feature Identifier
    # :object => Vm, Host, etc.

    # TODO
    # group = self.extract_objects(group)
    # return true if self.filters.nil? # TODO - Man need to check for filters like {:managed => [], :belongsto => []}
    #
    # feature_type = MiqProductFeature.feature_details(identifier)[:feature_type]
    #
    # self.filters = MiqUserScope.hash_to_scope(self.filters) unless self.filters.kind_of?(MiqUserScope)

    true # Remove once this is implemented
  end

  def self.next_sequence
    maximum(:sequence).to_i + 1
  end

  def self.seed
    role_map_file = File.expand_path(File.join(FIXTURE_DIR, "role_map.yaml"))
    root_tenant = Tenant.root_tenant
    if File.exist?(role_map_file)
      filter_map_file = File.expand_path(File.join(FIXTURE_DIR, "filter_map.yaml"))
      ldap_to_filters = File.exist?(filter_map_file) ? YAML.load_file(filter_map_file) : {}

      role_map = YAML.load_file(role_map_file)
      order = role_map.collect(&:keys).flatten
      groups_to_roles = role_map.each_with_object({}) { |g, h| h[g.keys.first] = g[g.keys.first] }
      seq = 1
      order.each do |g|
        group = find_by_description(g) || new(:description => g)
        user_role = MiqUserRole.find_by_name("EvmRole-#{groups_to_roles[g]}")
        if user_role.nil?
          _log.warn("Unable to find user_role 'EvmRole-#{groups_to_roles[g]}' for group '#{g}'")
          next
        end
        group.miq_user_role = user_role
        group.sequence      = seq
        group.filters       = ldap_to_filters[g]
        group.group_type    = SYSTEM_GROUP
        group.tenant        = root_tenant

        if group.changed?
          mode = group.new_record? ? "Created" : "Updated"
          group.save!
          _log.info("#{mode} Group: #{group.description} with Role: #{user_role.name}")
        end

        seq += 1
      end
    end

    # find any default tenant groups that do not have a role
    tenant_role = MiqUserRole.default_tenant_role
    if tenant_role
      tenant_groups.where(:miq_user_role_id => nil).each do |group|
        group.update_attributes(:miq_user_role => tenant_role)
      end
    else
      _log.warn("Unable to find default tenant role for tenant access")
    end
  end

  def self.get_ldap_groups_by_user(user, bind_dn, bind_pwd)
    auth = VMDB::Config.new("vmdb").config[:authentication]
    auth[:group_memberships_max_depth] ||= User::DEFAULT_GROUP_MEMBERSHIPS_MAX_DEPTH

    username = user.kind_of?(self) ? user.userid : user
    ldap = MiqLdap.new

    raise "Bind failed for user #{bind_dn}" unless ldap.bind(ldap.fqusername(bind_dn), bind_pwd)
    user_obj = ldap.get_user_object(ldap.normalize(ldap.fqusername(username)))
    raise "Unable to find user #{username} in directory" if user_obj.nil?

    ldap.get_memberships(user_obj, auth[:group_memberships_max_depth])
  end

  def self.get_httpd_groups_by_user(user)
    require "dbus"

    username = user.kind_of?(self) ? user.userid : user

    sysbus = DBus.system_bus
    ifp_service   = sysbus["org.freedesktop.sssd.infopipe"]
    ifp_object    = ifp_service.object "/org/freedesktop/sssd/infopipe"
    ifp_object.introspect
    ifp_interface = ifp_object["org.freedesktop.sssd.infopipe"]
    begin
      user_groups = ifp_interface.GetUserGroups(user)
    rescue => err
      raise "Unable to get groups for user #{username} - #{err}"
    end
    user_groups.first
  end

  def get_user_scope(options = {})
    scope = filters.kind_of?(MiqUserScope) ? filters : MiqUserScope.hash_to_scope(filters)

    scope.get_filters(options)
  end

  def get_filters(type = nil)
    if type
      (filters.respond_to?(:key?) && filters[type.to_s]) || []
    else
      filters || {"managed" => [], "belongsto" => []}
    end
  end

  def has_filters?
    get_managed_filters.present? || get_belongsto_filters.present?
  end

  def get_managed_filters
    get_filters("managed")
  end

  def get_belongsto_filters
    get_filters("belongsto")
  end

  def set_filters(type, filter)
    self.filters ||= {}
    self.filters[type.to_s] = filter
  end

  def set_managed_filters(filter)
    set_filters("managed", filter)
  end

  def set_belongsto_filters(filter)
    set_filters("belongsto", filter)
  end

  def miq_user_role_name
    miq_user_role.nil? ? nil : miq_user_role.name
  end

  def system_group?
    group_type == SYSTEM_GROUP
  end

  # @return true if this is a default tenant group
  def tenant_group?
    group_type == TENANT_GROUP
  end

  # Asks about the tenant's default_miq_group
  #
  # NOTE: this is the old definition for `tenant_group?`
  #
  # @return true if this is assigned to the tenant as the default tenant
  # @return false if the tenant is being deleted or pointing to a different group
  def referenced_by_tenant?
    tenant.try(:default_miq_group_id) == id
  end

  def read_only
    system_group? || tenant_group?
  end
  alias_method :read_only?, :read_only

  def user_count
    users.count
  end

  def description=(val)
    super(val.to_s.strip)
  end

  def ordered_widget_sets
    if settings && settings[:dashboard_order]
      MiqWidgetSet.find_with_same_order(settings[:dashboard_order]).to_a
    else
      miq_widget_sets.sort_by { |a| a.name.downcase }
    end
  end

  def self.create_tenant_group(tenant)
    tenant_full_name = (tenant.ancestors.map(&:name) + [tenant.name]).join("/")

    create_with(
      :description         => "Tenant #{tenant_full_name} access",
      :group_type          => TENANT_GROUP,
      :default_tenant_role => MiqUserRole.default_tenant_role
    ).find_or_create_by!(:tenant_id => tenant.id)
  end

  def self.sort_by_desc
    all.sort_by { |g| g.description.downcase }
  end

  def self.tenant_groups
    where(:group_type => TENANT_GROUP)
  end

  def self.non_tenant_groups
    where.not(:group_type => TENANT_GROUP)
  end

  def self.with_current_user_groups
    current_user = User.current_user
    current_user.admin_user? ? all : where(:id => current_user.miq_group_ids)
  end

  def self.valid_filters?(filters_hash)
    return true  unless filters_hash                  # nil ok
    return false unless filters_hash.kind_of?(Hash)   # must be Hash
    return true  if filters_hash.blank?               # {} ok
    filters_hash["managed"].present? || filters_hash["belongsto"].present?
  end

  private

  # if this tenant is changing, make sure this is not a default group
  # NOTE: old tenant is Tenant.find(tenant_id_was)
  def validate_default_tenant
    if tenant_id_was && tenant_group?
      errors.add(:tenant_id, "cant change the tenant of a default group")
    end
  end

  def ensure_can_be_destroyed
    raise "Still has users assigned." unless users.empty?
    raise "A tenant default group can not be deleted" if tenant_group? && referenced_by_tenant?
    raise "A read only group cannot be deleted." if system_group?
  end
end
