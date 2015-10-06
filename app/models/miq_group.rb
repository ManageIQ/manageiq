class MiqGroup < ActiveRecord::Base
  default_scope { where(conditions_for_my_region_default_scope) }

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

  validates_presence_of   :description, :guid
  validates_uniqueness_of :description, :guid

  before_destroy do |g|
    raise "Still has users assigned." unless g.users.empty?
    raise "A read only group cannot be deleted." if g.read_only
  end

  serialize :filters
  serialize :settings

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

  def self.add(attrs)
    group = new(attrs)
    if group.resource.nil?
      groups = where(:resource_id => nil, :resource_type => nil).order("sequence DESC")
    else
      groups = group.resource.miq_groups.order("sequence DESC")
    end
    group.sequence = groups.first.nil? ? 1 : groups.first.sequence + 1
    group.save!

    group
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
          _log.warn("Unable to find user_role 'EvmRole-#{groups_to_roles[group]}' for group '#{g}'")
          next
        end
        group.miq_user_role = user_role
        group.sequence      = seq
        group.filters       = ldap_to_filters[g]
        group.group_type    = "system"
        group.tenant        = root_tenant

        mode = group.new_record? ? "Created" : "Added"
        group.save!
        _log.info("#{mode} Group: #{group.description} with Role: #{user_role.name}")

        seq += 1
      end
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

  def read_only
    group_type == "system"
  end

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

  def self.sort_by_desc
    all.sort_by { |g| g.description.downcase }
  end
end
