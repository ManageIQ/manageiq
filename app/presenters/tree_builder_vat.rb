class TreeBuilderVat < TreeBuilderDatacenter

  def initialize(name, type, sandbox, build = true, root = nil, vat = nil)
    sandbox[:vat] = vat unless vat.nil?
    @vat = sandbox[:vat]
    @user_id = User.current_userid
    super(name, type, sandbox, build, root)
  end

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

  def set_locals_for_render
    locals = super
    locals.merge!(
        :id_prefix                   => "vat_",
        :autoload                    => true,
        :url                         => '/vm/show/',
        :open_close_all_on_dbl_click => true,
        :onclick                     => 'miqOnClickHostNet',
    )
  end

  def root_options
    image = "vendor-#{@root.image_name}".to_sym
    [@root.name, @root.name, image]
  end

  def x_get_tree_roots(count_only = false, _options)
    folders = count_only_or_objects(count_only, @root.children.first.folders_only)
    datacenters = count_only_or_objects(count_only, @root.children.first.datacenters_only)
    folders + datacenters
  end

  def x_get_tree_datacenter_kids(parent, count_only = false, type)
    # get rid of unwanted folder level
    parent = @vat ? parent.folders.find{|x| x.name == "vm"} : parent.folders.find{|x| x.name == "host"}
    x_get_tree_folder_kids(parent, count_only, type)
  end

  def x_get_tree_folder_kids(parent, count_only, _type)
    objects = count_only ? 0 : []

    if parent.name == "Datacenters"
      folders = count_only_or_objects(count_only, parent.folders_only)
      datacenters = count_only_or_objects(count_only, parent.datacenters_only)
      objects = folders + datacenters
    elsif parent.name == "host" && parent.parent.kind_of?(Datacenter)
      unless @vat
        folders = count_only_or_objects(count_only, parent.folders_only)
        clusters = count_only_or_objects(count_only, parent.clusters)
        hosts = count_only_or_objects(count_only, parent.hosts)
        objects = folders + clusters + hosts
      end
    elsif parent.name == "datastore" && parent.parent.kind_of?(Datacenter)
      # Skip showing the datastore folder and sub-folders
    elsif parent.name == "vm" && parent.parent.kind_of?(Datacenter)
      if @vat
        folders = count_only_or_objects(count_only, parent.folders_only)
        vms = count_only_or_objects(count_only, parent.vms)
        objects = folders + vms
      end
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