class MiqGroup < ApplicationRecord
  USER_GROUP   = "user"
  SYSTEM_GROUP = "system"
  TENANT_GROUP = "tenant"

  belongs_to :tenant
  has_one    :entitlement, :dependent => :destroy, :autosave => true
  has_one    :miq_user_role, :through => :entitlement
  has_and_belongs_to_many :users
  has_many   :vms,         :dependent => :nullify
  has_many   :miq_templates, :dependent => :nullify
  has_many   :miq_reports, :dependent => :nullify
  has_many   :miq_report_results, :dependent => :nullify
  has_many   :miq_widget_contents, :dependent => :destroy
  has_many   :miq_widget_sets, :as => :owner, :dependent => :destroy
  has_many   :miq_product_features, :through => :miq_user_role
  has_many   :authentications, :dependent => :nullify

  virtual_delegate :miq_user_role_name, :to => :entitlement, :allow_nil => true
  virtual_column :read_only,          :type => :boolean
  virtual_has_one :sui_product_features, :class_name => "Array"

  delegate :self_service?, :limited_self_service?, :to => :miq_user_role, :allow_nil => true

  validates :description, :presence => true, :unique_within_region => { :match_case => false }
  validate :validate_default_tenant, :on => :update, :if => :tenant_id_changed?
  before_destroy :ensure_can_be_destroyed
  after_destroy :reset_current_group_for_users

  # For REST API compatibility only; Don't use otherwise!
  accepts_nested_attributes_for :entitlement

  serialize :settings

  default_value_for :group_type, USER_GROUP
  default_value_for(:sequence) { next_sequence }

  acts_as_miq_taggable
  include CustomAttributeMixin
  include ActiveVmAggregationMixin
  include TimezoneMixin
  include TenancyMixin
  include CustomActionsMixin

  alias_method :current_tenant, :tenant

  def name
    description
  end

  def settings
    current = super
    return if current.nil?

    self.settings = current.with_indifferent_access
    super
  end

  def settings=(new_settings)
    indifferent_settings = new_settings.try(:with_indifferent_access)
    super(indifferent_settings)
  end

  def self.with_roles_excluding(identifier)
    where.not(:id => MiqGroup.unscope(:select).joins(:miq_product_features)
                             .where(:miq_product_features => {:identifier => identifier})
                             .select(:id))
  end

  def self.next_sequence
    maximum(:sequence).to_i + 1
  end

  def self.seed
    role_map_file = FIXTURE_DIR.join("role_map.yaml")
    role_map = YAML.load_file(role_map_file) if role_map_file.exist?
    return unless role_map

    filter_map_file = FIXTURE_DIR.join("filter_map.yaml")
    ldap_to_filters = filter_map_file.exist? ? YAML.load_file(filter_map_file) : {}
    root_tenant = Tenant.root_tenant

    groups = where(:group_type => SYSTEM_GROUP, :tenant_id => Tenant.root_tenant)
               .includes(:entitlement).index_by(&:description)
    roles  = MiqUserRole.where("name like 'EvmRole-%'").index_by(&:name)

    role_map.each_with_index do |(group_name, role_name), index|
      group = groups[group_name] || new(:description => group_name)
      user_role = roles["EvmRole-#{role_name}"]
      if user_role.nil?
        raise StandardError,
              _("Unable to find user_role 'EvmRole-%{role_name}' for group '%{group_name}'") %
                {:role_name => role_name, :group_name => group_name}
      end
      group.miq_user_role       = user_role if group.entitlement.try(:miq_user_role_id) != user_role.id
      group.sequence            = index + 1
      group.entitlement.filters = ldap_to_filters[group_name]
      group.group_type          = SYSTEM_GROUP
      group.tenant              = root_tenant

      if group.changed?
        mode = group.new_record? ? "Created" : "Updated"
        group.save!
        _log.info("#{mode} Group: #{group.description} with Role: #{user_role.name}")
      end
    end

    # find any default tenant groups that do not have a role
    tenant_role = MiqUserRole.default_tenant_role
    if tenant_role
      tenant_groups.includes(:entitlement).where(:entitlements => {:miq_user_role_id => nil}).each do |group|
        if group.entitlement.present? # Relation is read-only if present
          Entitlement.update(group.entitlement.id, :miq_user_role => tenant_role)
        else
          group.update_attributes(:miq_user_role => tenant_role)
        end
      end
    else
      _log.warn("Unable to find default tenant role for tenant access")
    end
  end

  def self.strip_group_domains(group_list)
    group_list.collect { |group| group.gsub(/@.*/, '') }
  end

  def self.get_ldap_groups_by_user(user, bind_dn, bind_pwd)
    username = user.kind_of?(self) ? user.userid : user
    ldap = MiqLdap.new

    unless ldap.bind(ldap.fqusername(bind_dn), bind_pwd)
      raise _("Bind failed for user %{user_name}") % {:user_name => bind_dn}
    end
    user_obj = ldap.get_user_object(ldap.normalize(ldap.fqusername(username)))
    raise _("Unable to find user %{user_name} in directory") % {:user_name => username} if user_obj.nil?

    ldap.get_memberships(user_obj, ::Settings.authentication.group_memberships_max_depth)
  end

  def self.get_httpd_groups_by_user(user)
    if MiqEnvironment::Command.is_podified?
      get_httpd_groups_by_user_via_dbus_api_service(user)
    else
      get_httpd_groups_by_user_via_dbus(user)
    end
  end

  def self.get_httpd_groups_by_user_via_dbus(user)
    require "dbus"

    username = user.kind_of?(self) ? user.userid : user

    sysbus = DBus.system_bus
    ifp_service   = sysbus["org.freedesktop.sssd.infopipe"]
    ifp_object    = ifp_service.object("/org/freedesktop/sssd/infopipe")
    ifp_object.introspect
    ifp_interface = ifp_object["org.freedesktop.sssd.infopipe"]
    begin
      user_groups = ifp_interface.GetUserGroups(user)
    rescue => err
      raise _("Unable to get groups for user %{user_name} - %{error}") % {:user_name => username, :error => err}
    end
    strip_group_domains(user_groups.first)
  end

  def self.get_httpd_groups_by_user_via_dbus_api_service(user)
    require_dependency "httpd_dbus_api"

    groups = HttpdDBusApi.new.user_groups(user)
    strip_group_domains(groups)
  end

  def get_filters(type = nil)
    entitlement.try(:get_filters, type)
  end

  def has_filters?
    entitlement.try(:has_filters?) || false
  end

  def get_managed_filters
    entitlement.try(:get_managed_filters) || []
  end

  def get_belongsto_filters
    entitlement.try(:get_belongsto_filters) || []
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

  virtual_total :user_count, :users

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
      :default_tenant_role => MiqUserRole.default_tenant_role
    ).find_or_create_by!(
      :group_type => TENANT_GROUP,
      :tenant_id  => tenant.id,
    )
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

  def self.non_tenant_groups_in_my_region
    in_my_region.non_tenant_groups
  end

  # parallel to User.with_groups - only show these groups
  def self.with_groups(miq_group_ids)
    where(:id => miq_group_ids)
  end

  def single_group_users?
    group_user_ids = user_ids
    return false if group_user_ids.empty?
    users.includes(:miq_groups).where(:id => group_user_ids).where.not(:miq_groups => {:id => id}).count != group_user_ids.size
  end

  def sui_product_features
    return [] unless miq_user_role.allows?(:identifier => 'sui')
    MiqProductFeature.feature_all_children('sui').each_with_object([]) do |sui_feature, sui_features|
      sui_features << sui_feature if miq_user_role.allows?(:identifier => sui_feature)
    end
  end

  def self.display_name(number = 1)
    n_('Group', 'Groups', number)
  end

  private

  # if this tenant is changing, make sure this is not a default group
  # NOTE: old tenant is Tenant.find(tenant_id_was)
  def validate_default_tenant
    if tenant_id_was && tenant_group?
      errors.add(:tenant_id, "cant change the tenant of a default group")
    end
  end

  def current_user_group?
    id == current_user_group.try(:id)
  end

  def ensure_can_be_destroyed
    raise _("The login group cannot be deleted") if current_user_group?
    raise _("The group has users assigned that do not belong to any other group") if single_group_users?
    raise _("A tenant default group can not be deleted") if tenant_group? && referenced_by_tenant?
    raise _("A read only group cannot be deleted.") if system_group?
  end

  def reset_current_group_for_users
    User.where(:id => user_ids, :current_group_id => id).each(&:change_current_group)
  end
end
