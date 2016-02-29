class UserGroup < ApplicationRecord
  has_and_belongs_to_many :users
  has_and_belongs_to_many :miq_groups
  has_many   :vms,                 :dependent => :nullify
  has_many   :miq_templates,       :dependent => :nullify
  has_many   :miq_reports,         :dependent => :nullify
  has_many   :miq_report_results,  :dependent => :nullify
  has_many   :miq_widget_contents, :dependent => :destroy
  has_many   :miq_widget_sets,     :dependent => :destroy, as: :owner

  validates :description, :presence => true, :uniqueness => true

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
      user_group = UserGroup.find_by_description(group_name) || new(:description => group_name)

      if user_group.changed?
        mode = user_group.new_record? ? "Created" : "Updated"
        user_group.save!
        _log.info("#{user_group.new_record? ? 'Created' : 'Updated'} UserGroup: #{user_group.description}")
      end

      entitlement = begin
                      existing_id = (user_role.miq_group_ids & user_group.miq_group_ids).first
                      if existing_id.present?
                        MiqGroup.find(existing_id)
                      else
                        group = MiqGroup.new(:miq_user_role => user_role)
                        group.user_groups << user_group
                        group
                      end
                    end

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
end
