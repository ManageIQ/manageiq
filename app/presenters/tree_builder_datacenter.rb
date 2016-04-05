class TreeBuilderDatacenter < TreeBuilder
  # cluster = EmsCluster.find(@sb[:cl_id])
  # user_id = session[:userid]

  def initialize(name, type, sandbox, build = true, root = nil)
    sandbox[:datacenter_root] = root if root
    @root = sandbox[:datacenter_root]
    @user_id = User.current_userid
    super(name, type, sandbox, build)
  end

  # Get correct prefix
  def self.prefix_type(object)
    case object
      when Host         then "Host"
      when EmsCluster   then "Cluster"
      when ResourcePool then "Resource Pool"
      when Datacenter   then "Datacenter"
      when Vm           then "Vm"
      else                   ""
    end
  end

  private

  # always same
  def tree_init_options(_tree_name)
    {:full_ids            => true,
     :tooltip_forced      => true,
     :tooltip_suffix      => _(" (Click to view)"),
     :tooltip_prefix_type => [self.class, :prefix_type],
     }
  end

  # just change id_prefix
  # TODO nastavit
  def set_locals_for_render
    locals = super
    locals.merge!(
        :id_prefix                   => "dc_",
        :autoload                    => true,
        :url                         => '/vm/show/',
        :open_close_all_on_dbl_click => true,
        :onclick                     => 'miqOnClickHostNet',
    )
  end

  def root_options
    if @root.kind_of?(EmsCluster)
      [@root.name, _("Cluster: %{name}") % {:name => @root.name}, "cluster"]
    elsif @root.kind_of?(ResourcePool)
      [@root.name, _("Resource Pool: %{name}") % {:name => @root.name}, @root.vapp ? "vapp" : "resource_pool"]
    end
  end

  # level 1 - vratit cl_kids z ems_cluster
  def x_get_tree_roots(count_only = false, _options)
    if @root.kind_of?(EmsCluster)
      hosts = count_only_or_objects(count_only, @root.hosts)
      resource_pools = count_only_or_objects(count_only, @root.resource_pools)
      vms = count_only_or_objects(count_only, @root.vms)
      hosts + resource_pools + vms
    elsif @root.kind_of?(ResourcePool)
      resource_pools = count_only_or_objects(count_only, @root.resource_pools)
      vms = count_only_or_objects(count_only, @root.vms)
      resource_pools + vms
    elsif @root.kind_of?(ExtManagementSystem)
      count_only_or_objects(count_only, @root.children)
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
      hosts = count_only_or_objects(count_only, parent.hosts)
      objects = folders + clusters + hosts
    elsif parent.name == "datastore" && parent.parent.kind_of?(Datacenter)
      # Skip showing the datastore folder and sub-folders
    elsif parent.name == "vm" && parent.parent.kind_of?(Datacenter)
    else
      folders = count_only_or_objects(count_only, parent.folders_only)
      datacenters = count_only_or_objects(count_only, parent.datacenters_only)
      clusters = count_only_or_objects(count_only, parent.clusters)
      hosts = count_only_or_objects(count_only, parent.hosts)
      vms = count_only_or_objects(count_only, parent.vms)
      objects = folders + datacenters + clusters + hosts + vms
    end
    objects
  end

  def x_get_tree_host_kids(parent, count_only)
    objects = count_only ? 0 : []
    if parent.authorized_for_user?(@user_id)
      objects += count_only_or_objects(count_only, parent.resource_pools)
      if parent.default_resource_pool
        objects += count_only_or_objects(count_only, parent.default_resource_pool.vms)
      end
    end
    objects
  end

  def  x_get_tree_cluster_kids(parent, count_only = false)
    resource_pools = count_only_or_objects(count_only, parent.resource_pools)
    hosts = count_only_or_objects(count_only, parent.hosts)
    vms = count_only_or_objects(count_only, parent.vms)
    resource_pools + hosts + vms
  end

  def x_get_resource_pool_kids(parent, count_only = false)
    resource_pools = count_only_or_objects(count_only, parent.resource_pools)
    vms = count_only_or_objects(count_only, parent.vms)
    resource_pools + vms
  end
end