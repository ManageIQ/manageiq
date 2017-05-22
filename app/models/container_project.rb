class ContainerProject < ApplicationRecord
  include SupportsFeatureMixin
  include CustomAttributeMixin
  include ArchivedMixin
  include_concern 'Purging'
  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many :container_groups
  has_many :container_routes
  has_many :container_replicators
  has_many :container_services
  has_many :containers, :through => :container_groups
  has_many :container_definitions, :through => :container_groups
  has_many :container_images, -> { distinct }, :through => :container_groups
  has_many :container_nodes, -> { distinct }, :through => :container_groups
  has_many :container_quotas
  has_many :container_quota_items, :through => :container_quotas
  has_many :container_limits
  has_many :container_limit_items, :through => :container_limits
  has_many :container_builds
  has_many :container_templates
  has_many :archived_container_groups, :foreign_key => "old_container_project_id", :class_name => "ContainerGroup"

  # Needed for metrics
  has_many :metrics,                :as => :resource
  has_many :metric_rollups,         :as => :resource
  has_many :vim_performance_states, :as => :resource

  has_many :labels, -> { where(:section => "labels") }, :class_name => "CustomAttribute", :as => :resource, :dependent => :destroy

  virtual_total :groups_count,      :container_groups
  virtual_total :services_count,    :container_services
  virtual_total :routes_count,      :container_routes
  virtual_total :replicators_count, :container_replicators
  virtual_total :containers_count,  :container_definitions
  virtual_total :images_count,      :container_images

  include EventMixin
  include Metric::CiMixin
  include ContainerResourceParentMixin

  PERF_ROLLUP_CHILDREN = :all_container_groups

  def all_container_groups
    ContainerGroup.where(:container_project_id => id).or(ContainerGroup.where(:old_container_project_id => id))
  end

  acts_as_miq_taggable

  def event_where_clause(assoc = :ems_events)
    case assoc.to_sym
    when :ems_events, :event_streams
      # TODO: improve relationship using the id
      ["container_namespace = ? AND #{events_table_name(assoc)}.ems_id = ?", name, ems_id]
    when :policy_events
      # TODO: implement policy events and its relationship
      ["ems_id = ?", ems_id]
    end
  end

  def perf_rollup_parents(interval_name = nil)
    []
  end

  def disconnect_inv
    return if ems_id.nil?
    _log.info "Disconnecting Container Project [#{name}] id [#{id}] from EMS [#{ext_management_system.name}]" \
    "id [#{ext_management_system.id}] "
    self.old_ems_id = ems_id
    self.ext_management_system = nil
    self.deleted_on = Time.now.utc
    save
  end

  def add_role_to_user(user_name, role_name)
    role_binding = get_resource_by_name(role_name, 'RoleBinding', name).to_h
    # If the particular binding doesn't exist or it doesn't have a userNames
    # attribute, create a new binding.
    if role_binding.nil? || !role_binding.key?(:userNames)

    end

    if role_binding.nil?
      new_role_binding = Kubeclient::Resource.new(:kind       => 'RoleBinding',
                                                  :apiVersion => 'v1',
                                                  :metadata   => {:namespace => name,
                                                                  :name      => role_name},
                                                  :roleRef    => {:name => role_name},
                                                  :userNames  => [user_name])
      create_resource(new_role_binding.to_h)
    elsif !role_binding.key?(:userNames)
      role_binding[:userNames] = [user_name]
      update_in_provider(role_binding.to_h)
    else
      role_binding[:userNames] = (role_binding[:userNames] + [user_name]).uniq
      update_in_provider(role_binding.to_h)
    end
  end

  def subjects_with_role(role_name)
    role_binding = get_resource_by_name(role_name, 'RoleBinding', name).to_h
    if role_binding.nil? || !role_binding.key?(:subjects)
      return nil
    end
    role_binding[:subjects]
  end
end
