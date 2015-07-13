class ResourcePool < ActiveRecord::Base
  include ReportableMixin
  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => "ems_id"

  include SerializedEmsRefObjMixin
  include FilterableMixin

  include RelationshipMixin
  self.default_relationship_type = "ems_metadata"

  include AggregationMixin
  # Since we've overridden the implementation of methods from AggregationMixin,
  # we must also override the :uses portion of the virtual columns.
  override_aggregation_mixin_virtual_columns_uses(:all_hosts, :all_relationships)

  include MiqPolicyMixin
  include AsyncDeleteMixin
  include WebServiceAttributeMixin


  virtual_column :v_parent_cluster,        :type => :string,  :uses => :all_relationships
  virtual_column :v_parent_host,           :type => :string,  :uses => :all_relationships
  virtual_column :v_parent_resource_pool,  :type => :string,  :uses => :all_relationships
  virtual_column :v_parent_datacenter,     :type => :string,  :uses => :all_relationships
  virtual_column :v_parent_folder,         :type => :string,  :uses => :all_relationships
  virtual_column :v_direct_miq_templates,  :type => :integer, :uses => :all_relationships
  virtual_column :v_direct_vms,            :type => :integer, :uses => :all_relationships
  virtual_column :v_total_vms,             :type => :integer, :uses => :all_relationships
  virtual_column :v_total_miq_templates,   :type => :integer, :uses => :all_relationships

  virtual_has_many :vms_and_templates, :uses => :all_relationships
  virtual_has_many :vms,               :uses => :all_relationships
  virtual_has_many :miq_templates,     :uses => :all_relationships

  def hidden?
    is_default?
  end

  #
  # Relationship methods
  #

  # Resource Pool relationship methods
  def resource_pools
    self.children(:of_type => 'ResourcePool').sort_by { |c| c.name.downcase }
  end

  alias add_resource_pool set_child
  alias remove_resource_pool remove_child

  def remove_all_resource_pools
    self.remove_all_children(:of_type => 'ResourcePool')
  end

  def root_resource_pool
    rel = self.path_rels(:of_type => 'ResourcePool').first
    rel.resource_id == self.id ? self : Relationship.resource(rel)
  end

  # VM relationship methods
  def vms_and_templates
    self.children(:of_type => 'VmOrTemplate').sort_by { |c| c.name.downcase }
  end
  alias direct_vms_and_templates vms_and_templates

  def miq_templates
    self.vms_and_templates.select { |v| v.kind_of?(MiqTemplate) }
  end
  alias direct_miq_templates miq_templates

  def vms
    self.vms_and_templates.select { |v| v.kind_of?(Vm) }
  end
  alias direct_vms vms

  def vm_and_template_ids
    Relationship.resource_pairs_to_ids(self.child_ids(:of_type => 'VmOrTemplate'))
  end

  def miq_template_ids
    self.miq_templates.collect(&:id)
  end
  alias direct_miq_template_ids miq_template_ids

  def vm_ids
    self.vms.collect(&:id)
  end
  alias direct_vm_ids vm_ids

  def total_direct_vms_and_templates
    self.child_count(:of_type => 'VmOrTemplate')
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
    self.descendant_count(:of_type => 'VmOrTemplate')
  end

  def total_miq_templates
    all_miq_templates.size
  end

  def total_vms
    all_vms.size
  end

  alias add_vm set_child
  alias remove_vm remove_child

  def remove_all_vms
    self.remove_all_children(:of_type => 'Vm')
  end

  # All RPs under this RP and all child RPs
  def all_resource_pools
    self.descendants(:of_type => 'ResourcePool').sort_by { |r| r.name.downcase }
  end

  # Parent relationship methods
  def parent_resource_pool
    self.parent(:of_type => 'ResourcePool')
  end

  def parent_cluster_or_host
    Relationship.resource(self.ancestor_rels(:of_type => ["EmsCluster", "Host"]).last)
  end

  def parent_cluster
    p = self.parent_cluster_or_host
    p.is_a?(EmsCluster) ? p : nil
  end

  def parent_host
    p = self.parent_cluster_or_host
    p.is_a?(Host) ? p : nil
  end

  def parent_datacenter
    self.detect_ancestor(:of_type => "EmsFolder") { |a| a.is_datacenter }
  end

  def parent_folder
    self.detect_ancestor(:of_type => "EmsFolder") { |a| !a.is_datacenter && !["host", "vm"].include?(a.name) } # TODO: Fix this to use EmsFolder#hidden?
  end

  # Overridden from AggregationMixin to provide hosts related to this RP
  def all_hosts
    p = self.parent_cluster_or_host
    p.is_a?(Host) ? [p] : p.all_hosts
  end

  def all_host_ids
    self.all_hosts.collect(&:id)
  end

  # Virtual cols for parents
  def v_parent_cluster
    p = self.parent_cluster
    return p ? p.name : ""
  end

  def v_parent_host
    p = self.parent_host
    return p ? p.name : ""
  end

  def v_parent_resource_pool
    p = self.parent_resource_pool
    return p ? p.name : ""
  end

  def v_parent_datacenter
    p = self.parent_datacenter
    return p ? p.name : ""
  end

  def v_parent_folder
    p = self.parent_folder
    return p ? p.name : ""
  end

  alias v_direct_vms           total_direct_vms
  alias v_direct_miq_templates total_direct_miq_templates

  alias v_total_vms           total_vms
  alias v_total_miq_templates total_miq_templates

  # TODO: Move this into a more "global" module for anything in the ems_metadata tree.
  def absolute_path_objs(*args)
    options = args.extract_options!
    objs = self.path
    objs = objs[1..-1] if options[:exclude_ems]
    objs = objs.reject { |o| o.respond_to?(:hidden?) && o.hidden? } if options[:exclude_hidden]
    return objs
  end

  def absolute_path(*args)
    absolute_path_objs(*args).collect(&:name).join("/")
  end
end
