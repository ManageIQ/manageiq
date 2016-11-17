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
    root_child = @root.children.first
    count_only_or_many_objects(count_only, root_child.folders_only, root_child.datacenters_only, "name")
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
      objects = count_only_or_many_objects(count_only, parent.folders_only, parent.datacenters_only, "name")
    elsif parent.name == "host" && parent.parent.kind_of?(Datacenter)
      unless @vat
        objects = count_only_or_many_objects(count_only, parent.folders_only, parent.clusters, parent.hosts, "name")
      end
    elsif parent.name == "datastore" && parent.parent.kind_of?(Datacenter)
      # Skip showing the datastore folder and sub-folders
    elsif parent.name == "vm" && parent.parent.kind_of?(Datacenter)
      if @vat
        objects = count_only_or_many_objects(count_only, parent.folders_only, parent.vms, "name")
      end
    else
      objects = count_only_or_many_objects(count_only, parent.folders_only, parent.datacenters_only,
                                           parent.clusters, parent.hosts, parent.vms, "name")
    end
    objects
  end
end
