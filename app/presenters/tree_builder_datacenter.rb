class TreeBuilderDatacenter < TreeBuilder
  has_kids_for Host, [:x_get_tree_host_kids]
  has_kids_for Datacenter, [:x_get_tree_datacenter_kids, :type]
  has_kids_for EmsFolder, [:x_get_tree_folder_kids, :type]
  has_kids_for EmsCluster, [:x_get_tree_cluster_kids]
  has_kids_for ResourcePool, [:x_get_resource_pool_kids]

  def node_builder
    TreeNodeBuilderDatacenter
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
      hosts = count_only_or_objects(count_only, @root.hosts, "name")
      resource_pools = count_only_or_objects(count_only, @root.resource_pools)
      vms = count_only_or_objects(count_only, @root.vms, "name")
      hosts + resource_pools + vms
    elsif @root.kind_of?(ResourcePool)
      resource_pools = count_only_or_objects(count_only, @root.resource_pools)
      vms = count_only_or_objects(count_only, @root.vms, "name")
      resource_pools + vms
    end
  end

  def x_get_tree_datacenter_kids(parent, count_only = false, _type)
    folders = count_only_or_objects(count_only, parent.folders)
    clusters = count_only_or_objects(count_only, parent.clusters)
    folders + clusters
  end

  def x_get_tree_folder_kids(parent, count_only, _type)
    objects = count_only ? 0 : []

    if parent.name == "Datacenters"
      folders = count_only_or_objects(count_only, parent.folders_only)
      datacenters = count_only_or_objects(count_only, parent.datacenters_only)
      objects = folders + datacenters
    elsif parent.name == "host" && parent.parent.kind_of?(Datacenter)
      folders = count_only_or_objects(count_only, parent.folders_only)
      clusters = count_only_or_objects(count_only, parent.clusters)
      hosts = count_only_or_objects(count_only, parent.hosts, "name")
      objects = folders + clusters + hosts
    elsif parent.name == "datastore" && parent.parent.kind_of?(Datacenter)
      # Skip showing the datastore folder and sub-folders
    elsif parent.name == "vm" && parent.parent.kind_of?(Datacenter)
      #
    else
      folders = count_only_or_objects(count_only, parent.folders_only)
      datacenters = count_only_or_objects(count_only, parent.datacenters_only)
      clusters = count_only_or_objects(count_only, parent.clusters)
      hosts = count_only_or_objects(count_only, parent.hosts, "name")
      vms = count_only_or_objects(count_only, parent.vms, "name")
      objects = folders + datacenters + clusters + hosts + vms
    end
    objects
  end

  def x_get_tree_host_kids(parent, count_only)
    objects = count_only ? 0 : []
    if parent.authorized_for_user?(@user_id)
      objects += count_only_or_objects(count_only, parent.resource_pools)
      if parent.default_resource_pool
        objects += count_only_or_objects(count_only, parent.default_resource_pool.vms, "name")
      end
    end
    objects
  end

  def x_get_tree_cluster_kids(parent, count_only = false)
    resource_pools = count_only_or_objects(count_only, parent.resource_pools)
    hosts = count_only_or_objects(count_only, parent.hosts, "name")
    vms = count_only_or_objects(count_only, parent.vms, "name")
    resource_pools + hosts + vms
  end

  def x_get_resource_pool_kids(parent, count_only = false)
    resource_pools = count_only_or_objects(count_only, parent.resource_pools)
    vms = count_only_or_objects(count_only, parent.vms, "name")
    resource_pools + vms
  end
end
