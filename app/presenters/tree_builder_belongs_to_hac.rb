class TreeBuilderBelongsToHac < TreeBuilder
  has_kids_for ExtManagementSystem, [:x_get_kids_provider]
  has_kids_for Datacenter, [:x_get_tree_datacenter_kids, :type]
  has_kids_for EmsCluster, [:x_get_tree_cluster_kids]
  has_kids_for ResourcePool, [:x_get_resource_pool_kids]

  def node_builder
    TreeNodeBuilderBelongsToHac
  end

  def initialize(name, type, sandbox, build = true, params)
    @edit = params[:edit]
    @group = params[:group]
    super(name, type, sandbox, build = true)
    @tree_state.x_tree(name)[:checkable] = @edit.present?

  end

  private

  def tree_init_options(_tree_name)
    {:full_ids => true, :add_root => false, :lazy => false}
  end

  def set_locals_for_render
    locals = super
    locals.merge!(locals.merge!(:id_prefix         => 'vat_',
                                :check_url         => "ops/rbac_group_field_changed/#{@group.id || "new"}___",
                                :oncheck           => @edit.nil? ? nil : "miqOnCheckUserFilters",
                                :checkboxes        => true,
                                :highlight_changes => true,
                                :cfmeNoClick       => true,
                                :onclick           => false))
  end

  def root_options
    []
  end

  def x_get_tree_roots(count_only, _options)
    count_only_or_objects(count_only, ExtManagementSystem.all)
  end

  def x_get_kids_provider(parent, count_only)
    kids = []
    parent.children.each do |child|
      # this node is not added to a tree
        kids.concat(child.folders_only)
        kids.concat(child.datacenters_only)
    end
    count_only_or_objects(count_only, kids)
  end

  def x_get_tree_datacenter_kids(parent, count_only = false, _type)
    kids = []
    parent.folders.each do |child|
      if child.kind_of?(EmsFolder) && child.name == "host"
        kids.concat(child.folders_only)
        kids.concat(child.clusters)
        kids.concat(child.hosts)
      end
    end
    count_only_or_objects(count_only, kids)
  end

  def x_get_tree_cluster_kids(parent, count_only)
    count_only_or_objects(count_only, parent.hosts) + count_only_or_objects(count_only, parent.resource_pools)
  end

  def x_get_resource_pool_kids(parent, count_only)
    count_only_or_objects(count_only, parent.is_default? ? parent.resource_pools : [])
  end

end
