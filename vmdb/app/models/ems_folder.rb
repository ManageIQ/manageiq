class EmsFolder < ActiveRecord::Base
  belongs_to :ext_management_system, :foreign_key => "ems_id"

  include ReportableMixin
  acts_as_miq_taggable

  include SerializedEmsRefObjMixin
  include ProviderObjectMixin

  include RelationshipMixin
  self.default_relationship_type = "ems_metadata"

  include AggregationMixin
  include MiqPolicyMixin

  virtual_has_many :vms_and_templates, :uses => :all_relationships
  virtual_has_many :vms,               :uses => :all_relationships
  virtual_has_many :miq_templates,     :uses => :all_relationships
  virtual_has_many :hosts,             :uses => :all_relationships

  NON_DISPLAY_FOLDERS = ['Datacenters', 'vm', 'host']

  def hidden?(overrides = {})
    ems = overrides[:ext_management_system] || ext_management_system
    return false unless ems.kind_of?(EmsVmware)

    p = overrides[:parent] || self.parent if NON_DISPLAY_FOLDERS.include?(name)

    case name
    when "Datacenters" then p.kind_of?(ExtManagementSystem)
    when "vm", "host"  then p.kind_of?(EmsFolder) && p.is_datacenter?
    else                    false
    end
  end

  #
  # Provider Object methods
  #
  # TODO: Vmware specific - Fix when we subclass EmsFolder

  def provider_object(connection)
    connection.getVimFolderByMor(self.ems_ref_obj)
  end

  def provider_object_release(handle)
    handle.release if handle rescue nil
  end

  #
  # Relationship methods
  #

  # Folder relationship methods
  def folders
    self.children(:of_type => 'EmsFolder').sort_by { |c| c.name.downcase }
  end

  alias add_folder set_child
  alias remove_folder remove_child

  def remove_all_folders
    self.remove_all_children(:of_type => 'EmsFolder')
  end

  def folders_only
    self.folders.select { |f| !f.is_datacenter }
  end

  def datacenters_only
    self.folders.select { |f| f.is_datacenter }
  end

  # Cluster relationship methods
  def clusters
    self.children(:of_type => 'EmsCluster').sort_by { |c| c.name.downcase }
  end

  alias add_cluster set_child
  alias remove_cluster remove_child

  def remove_all_clusters
    self.remove_all_children(:of_type => 'EmsCluster')
  end

  # Host relationship methods
  #   all_hosts and all_host_ids included from AggregationMixin
  def hosts
    self.children(:of_type => 'Host').sort_by { |c| c.name.downcase }
  end

  alias add_host set_child
  alias remove_host remove_child

  def remove_all_hosts
    self.remove_all_children(:of_type => 'Host')
  end

  # Vm relationship methods
  #   all_vms and all_vm_ids included from AggregationMixin
  def vms_and_templates
    self.children(:of_type => 'VmOrTemplate').sort_by { |c| c.name.downcase }
  end

  def miq_templates
    self.vms_and_templates.select { |v| v.kind_of?(MiqTemplate) }
  end

  def vms
    self.vms_and_templates.select { |v| v.kind_of?(Vm) }
  end

  alias add_vm set_child
  alias remove_vm remove_child

  def remove_all_vms
    self.remove_all_children(:of_type => 'Vm')
  end

  # Parent relationship methods
  def parent_datacenter
    self.detect_ancestor(:of_type => "EmsFolder") { |a| a.is_datacenter }
  end

  # TODO: refactor by vendor/hypervisor (currently, this assumes VMware)
  def register_host(host)
    log_header = "MIQ(EmsCluster.register_host)"
    host = Host.extract_objects(host)
    raise "Host cannot be nil" if host.nil?
    userid, password = host.auth_user_pwd(:default)
    network_address  = host.address

    with_provider_connection do |vim|
      handle = provider_object(vim)
      begin
        $log.info "#{log_header} Invoking addStandaloneHost with options: address => #{network_address}, #{userid}"
        cr_mor = handle.addStandaloneHost(network_address, userid, password)
      rescue VimFault => verr
        fault = verr.vimFaultInfo.fault
        raise if     fault.nil?
        raise unless fault.xsiType == "SSLVerifyFault"

        ssl_thumbprint = fault.thumbprint
        $log.info "#{log_header} Invoking addStandaloneHost with options: address => #{network_address}, userid => #{userid}, sslThumbprint => #{ssl_thumbprint}"
        cr_mor = handle.addStandaloneHost(network_address, userid, password, :sslThumbprint => ssl_thumbprint)
      end

      host_mor                   = vim.computeResourcesByMor[cr_mor].host.first
      host.ems_ref               = host_mor
      host.ems_ref_obj           = host_mor
      host.ext_management_system = self.ext_management_system
      host.save!
      self.add_host(host)
      host.refresh_ems
    end
  end

  # Folder pathing methods
  # TODO: Store the full path directly in the folder objects for performance reasons

  # Returns an array of all parent folders with options for excluding "hidden"
  #   folders.  Default options are:
  #     :exclude_root_folder         => false
  #     :exclude_non_display_folders => false
  def folder_path_objs(*args)
    options = args.extract_options!
    folders = self.path(:of_type => "EmsFolder")
    folders = folders[1..-1] if options[:exclude_root_folder]
    folders = folders.reject { |f| NON_DISPLAY_FOLDERS.include?(f.name) } if options[:exclude_non_display_folders]
    return folders
  end

  def folder_path(*args)
    self.folder_path_objs(*args).collect { |f| f.name }.join('/')
  end

  def child_folder_paths(*args)
    self.class.child_folder_paths(self, *args)
  end

  def self.child_folder_paths(folder, *args)
    options = args.extract_options!
    meth = options[:exclude_root_folder] ? :descendants_arranged : :subtree_arranged

    subtree = folder.send(meth, :of_type => "EmsFolder")
    return child_folder_paths_recursive(subtree, options)
  end

  # Helper method for building the child folder paths given an arranged subtree.
  def self.child_folder_paths_recursive(subtree, options = {})
    options[:prefix] ||= ""
    subtree.each_with_object({}) do |(f, children), h|
      path = options[:prefix]
      unless options[:exclude_non_display_folders] && NON_DISPLAY_FOLDERS.include?(f.name)
        path = path.blank? ? f.name : "#{path}/#{f.name}"
        h[f.id] = path unless options[:exclude_datacenters] && f.is_datacenter?
      end
      h.merge!(child_folder_paths_recursive(children, options.merge(:prefix => path)))
    end
  end
  private_class_method :child_folder_paths_recursive
end
