class TreeBuilderVat < TreeBuilderDatacenter
  has_kids_for Datacenter, [:x_get_tree_datacenter_kids, :type]
  has_kids_for EmsFolder, [:x_get_tree_folder_kids, :type]

  def initialize(name, type, sandbox, build = true, root = nil, vat = nil)
    sandbox[:vat] = vat unless vat.nil?
    @vat = sandbox[:vat]
    @user_id = User.current_userid
    super(name, type, sandbox, build, root)
  end

  private

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
    # Get rid of unwanted folder level
    parent = @vat ? parent.folders.find { |x| x.name == "vm" } : parent.folders.find { |x| x.name == "host" }
    if parent.nil?
      count_only ? 0 : []
    else
      x_get_tree_folder_kids(parent, count_only, type)
    end
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
        hosts = count_only_or_objects(count_only, parent.hosts, "name")
        objects = folders + clusters + hosts
      end
    elsif parent.name == "datastore" && parent.parent.kind_of?(Datacenter)
      # Skip showing the datastore folder and sub-folders
    elsif parent.name == "vm" && parent.parent.kind_of?(Datacenter)
      if @vat
        folders = count_only_or_objects(count_only, parent.folders_only)
        vms = count_only_or_objects(count_only, parent.vms, "name")
        objects = folders + vms
      end
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
end
