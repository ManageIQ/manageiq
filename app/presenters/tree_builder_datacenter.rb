class TreeBuilderDatacenter < TreeBuilder
  has_kids_for Host, [:x_get_tree_host_kids]
  has_kids_for Datacenter, [:x_get_tree_datacenter_kids, :type]
  has_kids_for EmsFolder, [:x_get_tree_folder_kids, :type]
  has_kids_for EmsCluster, [:x_get_tree_cluster_kids]
  has_kids_for ResourcePool, [:x_get_resource_pool_kids]

  def override(node, object, pid, options)
    t = case object
        when Host         then _('Host')
        when EmsCluster   then _('Cluster')
        when ResourcePool then _('Resource Pool')
        when Datacenter   then _('Datacenter')
        when Vm           then _('VM')
        when Switch       then _('Switch')
        else                   ''
        end
    prefix = "#{t}: "
    suffix = _(" (Click to view)")
    node[:tooltip].prepend(prefix) if t.present? && !node[:tooltip].starts_with?(prefix)
    node[:tooltip].concat(suffix) unless node[:tooltip].ends_with?(suffix)
  end

  def initialize(name, type, sandbox, build = true, root = nil)
    sandbox[:datacenter_root] = TreeBuilder.build_node_id(root) if root
    @root = root
    unless @root
      model, id = TreeBuilder.extract_node_model_and_id(sandbox[:datacenter_root])
      @root = model.constantize.find_by(:id => id)
    end
    @user_id = User.current_userid
    super(name, type, sandbox, build)
  end

  private

  def tree_init_options(_tree_name)
    {:full_ids => true}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:autoload => true, :url => '/vm/show/', :onclick => 'miqOnClickHostNet')
  end

  def root_options
    if @root.kind_of?(EmsCluster)
      [@root.name, _("Cluster: %{name}") % {:name => @root.name}, "cluster"]
    elsif @root.kind_of?(ResourcePool)
      [@root.name, _("Resource Pool: %{name}") % {:name => @root.name}, @root.vapp ? "vapp" : "resource_pool"]
    end
  end

  def x_get_tree_roots(count_only = false, _options)
    if @root.kind_of?(EmsCluster)
      count_only_or_many_objects(count_only, @root.hosts, @root.resource_pools, @root.vms, "name")
    elsif @root.kind_of?(ResourcePool)
      count_only_or_many_objects(count_only, @root.resource_pools, @root.vms, "name")
    end
  end

  def x_get_tree_datacenter_kids(parent, count_only = false, _type)
    count_only_or_many_objects(count_only, parent.folders, parent.clusters, "name")
  end

  def x_get_tree_folder_kids(parent, count_only, _type)
    objects = count_only ? 0 : []

    if parent.name == "Datacenters"
      count_only_or_many_objects(count_only, parent.folders_only, parent.datacenters_only, "name")
    elsif parent.name == "host" && parent.parent.kind_of?(Datacenter)
      count_only_or_many_objects(count_only, parent.folders_only, parent.clusters, parent.hosts, "name")
    elsif parent.name == "datastore" && parent.parent.kind_of?(Datacenter)
      # Skip showing the datastore folder and sub-folders
    elsif parent.name == "vm" && parent.parent.kind_of?(Datacenter)
      #
    else
      count_only_or_many_objects(count_only, parent.folders_only, parent.datacenters_only, parent.clusters,
                                 parent.hosts, parent.vms, "name")
    end
    objects
  end

  def x_get_tree_host_kids(parent, count_only)
    if parent.authorized_for_user?(@user_id)
      count_only_or_many_objects(count_only,
                                 parent.resource_pools,
                                 -> { parent.default_resource_pool.try!(:vms) || [] }, "name")
    else
      count_only ? 0 : []
    end
  end

  def x_get_tree_cluster_kids(parent, count_only = false)
    count_only_or_many_objects(count_only, parent.resource_pools, parent.hosts, parent.vms, "name")
  end

  def x_get_resource_pool_kids(parent, count_only = false)
    count_only_or_many_objects(count_only, parent.resource_pools, parent.vms, "name")
  end
end
