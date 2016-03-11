class UserGroup < ApplicationRecord
  has_and_belongs_to_many :users
  has_one :miq_group

  validates :miq_group, :presence => true
  validates :description, :presence => true, :uniqueness => true

  def self.sort_by_desc
    all.sort_by { |g| g.description.downcase }
  end

  def self.seed
    role_map = seeded_role_map
    return unless seeded_role_map
    ldap_to_filters = seeded_filter_map
    root_tenant = Tenant.root_tenant

    role_map.each_with_index do |(group_name, role_name), index|
      user_role = MiqUserRole.find_by_name("EvmRole-#{role_name}")
      if user_role.nil?
        # Note MiqUserRoles should be seeded before MiqGroups
        raise StandardError, "Unable to find MiqUserRole 'EvmRole-#{role_name}' for group '#{group_name}'"
      end
      user_group = find_by_description(group_name) || new(:description => group_name)

      if user_group.changed?
        mode = user_group.new_record? ? "Created" : "Updated"
        user_group.save!
        _log.info("#{user_group.new_record? ? 'Created' : 'Updated'} UserGroup: #{user_group.description}")
      end

      user_group.miq_group ||= MiqGroup.new(:miq_user_role => user_role)

      entitlement = user_group.miq_group
      entitlement.sequence      = index + 1
      entitlement.filters       = ldap_to_filters[group_name]
      entitlement.group_type    = MiqGroup::SYSTEM_GROUP
      entitlement.tenant        = root_tenant

      if entitlement.changed?
        mode = entitlement.new_record? ? "Created" : "Updated"
        entitlement.save!
        _log.info("#{mode} MiqGroup linking UserGroup: #{user_group.description} with Role: #{user_role.name}")
      end
    end
  end

  def self.seeded_role_map
    role_map_file = FIXTURE_DIR.join("role_map.yaml")
    YAML.load_file(role_map_file) if role_map_file.exist?
  end
  private_class_method :seeded_role_map

  def self.seeded_filter_map
    filter_map_file = FIXTURE_DIR.join("filter_map.yaml")
    filter_map_file.exist? ? YAML.load_file(filter_map_file) : {}
  end
  private_class_method :seeded_filter_map

  def description=(val)
    super(val.to_s.strip)
  end

  def name
    description
  end

  def method_missing(method, *args)
    return miq_group.send(method, *args) if miq_group.respond_to?(method)
    super
  end
end
