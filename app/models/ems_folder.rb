class EmsFolder < ApplicationRecord
  include NewWithTypeStiMixin

  belongs_to :ext_management_system, :foreign_key => "ems_id"

  acts_as_miq_taggable

  include ProviderObjectMixin

  include RelationshipMixin
  self.default_relationship_type = "ems_metadata"

  include RelationshipsAggregationMixin
  include AggregationMixin::Methods
  include MiqPolicyMixin

  virtual_has_many :vms_and_templates, :uses => :all_relationships
  virtual_has_many :vms,               :uses => :all_relationships
  virtual_has_many :miq_templates,     :uses => :all_relationships
  virtual_has_many :hosts,             :uses => :all_relationships

  virtual_attribute :folder_path, :string, :uses => :all_relationships

  delegate :queue_name_for_ems_operations, :to => :ext_management_system, :allow_nil => true
  delegate :my_zone, :to => :ext_management_system

  #
  # Relationship methods
  #

  # Folder relationship methods
  def folders
    children(:of_type => 'EmsFolder')
  end

  alias_method :add_folder, :set_child
  alias_method :remove_folder, :remove_child

  def remove_all_folders
    remove_all_children(:of_type => 'EmsFolder')
  end

  def folders_only
    folders.select { |f| !f.kind_of?(Datacenter) }
  end

  def datacenters_only
    folders.select { |f| f.kind_of?(Datacenter) }
  end

  # Cluster relationship methods
  def clusters
    children(:of_type => 'EmsCluster')
  end

  alias_method :add_cluster, :set_child
  alias_method :remove_cluster, :remove_child

  def remove_all_clusters
    remove_all_children(:of_type => 'EmsCluster')
  end

  # Host relationship methods
  #   all_hosts and all_host_ids included from AggregationMixin
  def hosts
    children(:of_type => 'Host')
  end

  alias_method :add_host, :set_child
  alias_method :remove_host, :remove_child

  def remove_all_hosts
    remove_all_children(:of_type => 'Host')
  end

  # Vm relationship methods
  #   all_vms and all_vm_ids included from AggregationMixin
  def vms_and_templates
    children(:of_type => 'VmOrTemplate')
  end

  def miq_templates
    vms_and_templates.select { |v| v.kind_of?(MiqTemplate) }
  end

  def vms
    vms_and_templates.select { |v| v.kind_of?(Vm) }
  end

  alias_method :add_vm, :set_child
  alias_method :remove_vm, :remove_child

  def remove_all_vms
    remove_all_children(:of_type => 'Vm')
  end

  def storages
    children(:of_type => 'Storage')
  end

  alias add_storage set_child
  alias remove_storage remove_child

  def remove_all_storages
    remove_all_children(:of_type => 'Storage')
  end

  # Parent relationship methods
  def parent_datacenter
    detect_ancestor(:of_type => "EmsFolder") { |a| a.kind_of?(Datacenter) }
  end

  # Indicates if the folder is able to have child VMs
  def vm_folder?
    path.any? { |folder| folder.name == "vm" && folder.hidden? }
  end

  def register_host(_host)
    raise NotImplementedError, _("register_host must be implemented by a subclass")
  end

  # Folder pathing methods
  # TODO: Store the full path directly in the folder objects for performance reasons

  # Returns an array of all parent folders with options for excluding "hidden"
  #   folders.  Default options are:
  #     :exclude_root_folder         => false
  #     :exclude_non_display_folders => false
  def folder_path_objs(*args)
    options = args.extract_options!
    folders = path(:of_type => "EmsFolder")
    folders = folders[1..-1] if options[:exclude_root_folder]
    folders = folders.reject(&:hidden?) if options[:exclude_non_display_folders]
    folders
  end

  def folder_path(*args)
    folder_path_objs(*args).collect(&:name).join('/')
  end

  def child_folder_paths(*args)
    self.class.child_folder_paths(self, *args)
  end

  def self.child_folder_paths(folder, *args)
    options = args.extract_options!
    meth = options[:exclude_root_folder] ? :descendants_arranged : :subtree_arranged

    subtree = folder.send(meth, :of_type => "EmsFolder")
    child_folder_paths_recursive(subtree, options)
  end

  def self.display_name(number = 1)
    n_('Folder', 'Folders', number)
  end

  # Helper method for building the child folder paths given an arranged subtree.
  def self.child_folder_paths_recursive(subtree, options = {})
    options[:prefix] ||= ""
    subtree.each_with_object({}) do |(f, children), h|
      path = options[:prefix]
      unless options[:exclude_non_display_folders] && f.hidden?
        path = path.blank? ? f.name : "#{path}/#{f.name}"
        h[f.id] = path unless options[:exclude_datacenters] && f.kind_of?(Datacenter)
      end
      h.merge!(child_folder_paths_recursive(children, options.merge(:prefix => path)))
    end
  end
  private_class_method :child_folder_paths_recursive
end
