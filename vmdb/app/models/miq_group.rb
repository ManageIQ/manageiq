class MiqGroup < ActiveRecord::Base
  default_scope { where(self.conditions_for_my_region_default_scope) }

  belongs_to :miq_user_role
  belongs_to :role, :class_name => "UiTaskSet", :foreign_key => :ui_task_set_id
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

  # TODO: Commented out :ui_task_set_idfor work for implementing new RBAC design. This should be replaced with miq_group_id.
  validates_presence_of   :description, :guid #, :ui_task_set_id
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

  FIXTURE_DIR = File.join(Rails.root, "db/fixtures")

  def name
    self.description
  end

  def all_users
    User.all_users_of_group(self)
  end

  def self.allows?(group, options={})
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

    return true # Remove once this is implemented
  end

  def self.add(attrs)
    group = self.new(attrs)
    if group.resource.nil?
      groups = self.find(:all, :conditions => {:resource_id => nil, :resource_type => nil}, :order => "sequence DESC")
    else
      groups = group.resource.miq_groups.find(:all, :order => "sequence DESC")
    end
    group.sequence = groups.first.nil? ? 1 : groups.first.sequence + 1
    group.save!

    return group
  end

  def self.seed
    MiqRegion.my_region.lock do
      log_prefix = "MIQ(MiqGroup.seed)"
      role_map_file = File.expand_path(File.join(FIXTURE_DIR, "role_map.yaml"))
      if self.count == 0 && File.exist?(role_map_file)
        filter_map_file = File.expand_path(File.join(FIXTURE_DIR, "filter_map.yaml"))
        ldap_to_filters = File.exist?(filter_map_file) ? YAML.load_file(filter_map_file) : {}

        role_map = YAML.load_file(role_map_file)
        order = role_map.collect {|h| h.keys}.flatten
        groups_to_roles = role_map.inject({}) {|h, g| h[g.keys.first] = g[g.keys.first]; h}
        seq = 1
        order.each do |g|
          group = self.find_by_description(g) || self.new(:description => g)
          user_role = MiqUserRole.find_by_name("EvmRole-#{groups_to_roles[g]}")
          if user_role.nil?
            $log.warn("#{log_prefix} Unable to find user_role 'EvmRole-#{groups_to_roles[group]}' for group '#{g}'")
            next
          end
          group.miq_user_role = user_role
          group.sequence      = seq
          group.filters       = ldap_to_filters[g]
          group.group_type    = "system"

          mode = group.new_record? ? "Created" : "Added"
          group.save!
          $log.info("#{log_prefix} #{mode} Group: #{group.description} with Role: #{user_role.name}")

          seq += 1
        end
      else
        # Migrate legacy groups to have miq_user_roles if necessary
        self.all.each do |g|
          next unless g.group_type == "ldap"
          role_name = "EvmRole-#{g.description.split("-").last}"
          role = MiqUserRole.find_by_name(role_name)
          if role.nil? && g.role
            role_name = "EvmRole-#{g.role.name}"
            role = MiqUserRole.find_by_name(role_name)
          end
          g.update_attributes(
            :group_type    => "system",
            :miq_user_role => role
          )
        end
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

  def get_user_scope(options={})
    scope = self.filters.kind_of?(MiqUserScope) ? self.filters : MiqUserScope.hash_to_scope(self.filters)

    scope.get_filters(options)
  end

  def get_filters(type = nil)
    f = self.filters
    return f if type.nil?

    type = type.to_s
    return (f.respond_to?(:key) && f.key?(type)) ? f[type] : []
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
    self.miq_user_role.nil? ? nil : self.miq_user_role.name
  end

  def self_service_group?
    return false if self.miq_user_role.nil?
    self.miq_user_role.self_service_role?
  end
  alias self_service? self_service_group?

  def limited_self_service_group?
    return false if self.miq_user_role.nil?
    self.miq_user_role.limited_self_service_role?
  end
  alias limited_self_service? limited_self_service_group?

  def read_only
    self.group_type == "system"
  end

  def user_count
    self.users.count
  end

  def description=(val)
    super(val.to_s.strip)
  end
end
