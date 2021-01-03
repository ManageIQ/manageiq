class ResourcePool < ApplicationRecord
  include NewWithTypeStiMixin
  include TenantIdentityMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => "ems_id"
  has_many   :miq_events,            :as => :target, :dependent => :destroy

  include FilterableMixin

  include RelationshipMixin
  self.default_relationship_type = "ems_metadata"

  include RelationshipsAggregationMixin
  include AggregationMixin::Methods
  include MiqPolicyMixin
  include AsyncDeleteMixin

  virtual_has_many :vms_and_templates, :uses => :all_relationships
  virtual_has_many :vms,               :uses => :all_relationships
  virtual_has_many :miq_templates,     :uses => :all_relationships

  virtual_column :v_parent_cluster,        :type => :string,  :uses => :all_relationships
  virtual_column :v_parent_host,           :type => :string,  :uses => :all_relationships
  virtual_column :v_parent_resource_pool,  :type => :string,  :uses => :all_relationships
  virtual_column :v_parent_datacenter,     :type => :string,  :uses => :all_relationships
  virtual_column :v_parent_folder,         :type => :string,  :uses => :all_relationships
  virtual_column :v_direct_miq_templates,  :type => :integer, :uses => :all_relationships
  virtual_column :v_direct_vms,            :type => :integer, :uses => :all_relationships
  virtual_total  :v_total_vms,             :all_vms,          :uses => :all_relationships
  virtual_total  :v_total_miq_templates,   :all_miq_templates, :uses => :all_relationships

  def hidden?
    is_default?
  end

  #
  # Relationship methods
  #

  # Resource Pool relationship methods
  def resource_pools
    children(:of_type => 'ResourcePool')
  end

  alias_method :add_resource_pool, :set_child
  alias_method :remove_resource_pool, :remove_child

  def remove_all_resource_pools
    remove_all_children(:of_type => 'ResourcePool')
  end

  def root_resource_pool
    rel = path_rels(:of_type => 'ResourcePool').first
    rel.resource_id == id ? self : Relationship.resource(rel)
  end

  # VM relationship methods
  def vms_and_templates
    children(:of_type => 'VmOrTemplate')
  end
  alias_method :direct_vms_and_templates, :vms_and_templates

  def miq_templates
    vms_and_templates.select { |v| v.kind_of?(MiqTemplate) }
  end
  alias_method :direct_miq_templates, :miq_templates

  def vms
    vms_and_templates.select { |v| v.kind_of?(Vm) }
  end
  alias_method :direct_vms, :vms

  def vm_and_template_ids
    Relationship.resource_pairs_to_ids(child_ids(:of_type => 'VmOrTemplate'))
  end

  def miq_template_ids
    miq_templates.collect(&:id)
  end
  alias_method :direct_miq_template_ids, :miq_template_ids

  def vm_ids
    vms.collect(&:id)
  end
  alias_method :direct_vm_ids, :vm_ids

  def total_direct_vms_and_templates
    child_count(:of_type => 'VmOrTemplate')
  end

  def total_direct_miq_templates
    direct_miq_templates.size
  end

  def total_direct_vms
    direct_vms.size
  end

  # All VMs under this RP and all child RPs
  #   all_vms and all_vm_ids included from AggregationMixin
  def total_vms_and_templates
    descendant_count(:of_type => 'VmOrTemplate')
  end

  alias_method :add_vm, :set_child
  alias_method :remove_vm, :remove_child

  def remove_all_vms
    remove_all_children(:of_type => 'Vm')
  end

  # All RPs under this RP and all child RPs
  def all_resource_pools
    descendants(:of_type => 'ResourcePool')
  end

  # Parent relationship methods
  def parent_resource_pool
    parent(:of_type => 'ResourcePool')
  end

  def parent_cluster_or_host
    Relationship.resource(ancestor_rels(:of_type => ["EmsCluster", "Host"]).last)
  end

  def parent_cluster
    p = parent_cluster_or_host
    p if p.kind_of?(EmsCluster)
  end

  def parent_host
    p = parent_cluster_or_host
    p if p.kind_of?(Host)
  end

  def parent_datacenter
    detect_ancestor(:of_type => "EmsFolder") { |a| a.kind_of?(Datacenter) }
  end

  def parent_folder
    detect_ancestor(:of_type => "EmsFolder") { |a| !a.kind_of?(Datacenter) && !%w(host vm).include?(a.name) } # TODO: Fix this to use EmsFolder#hidden?
  end

  # Overridden from AggregationMixin to provide hosts related to this RP
  def all_hosts
    if p = parent_cluster_or_host
      p.kind_of?(Host) ? [p] : p.hosts
    else
      []
    end
  end

  def all_host_ids
    all_hosts.collect(&:id)
  end

  # Virtual cols for parents
  def v_parent_cluster
    p = parent_cluster
    p ? p.name : ""
  end

  def v_parent_host
    p = parent_host
    p ? p.name : ""
  end

  def v_parent_resource_pool
    p = parent_resource_pool
    p ? p.name : ""
  end

  def v_parent_datacenter
    p = parent_datacenter
    p ? p.name : ""
  end

  def v_parent_folder
    p = parent_folder
    p ? p.name : ""
  end

  alias_method :v_direct_vms,           :total_direct_vms
  alias_method :v_direct_miq_templates, :total_direct_miq_templates

  alias total_vms v_total_vms
  alias total_miq_templates v_total_miq_templates

  # TODO: Move this into a more "global" module for anything in the ems_metadata tree.
  def absolute_path_objs(*args)
    options = args.extract_options!
    objs = path
    objs = objs[1..-1] if options[:exclude_ems]
    objs = objs.reject { |o| o.respond_to?(:hidden?) && o.hidden? } if options[:exclude_hidden]
    objs
  end

  def absolute_path(*args)
    absolute_path_objs(*args).collect(&:name).join("/")
  end
end
