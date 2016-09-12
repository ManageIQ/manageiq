class TreeBuilderInfraNetworking < TreeBuilder
  has_kids_for ManageIQ::Providers::Vmware::InfraManager, [:x_get_tree_provider_kids]
  has_kids_for EmsCluster, [:x_get_tree_cluster_kids]
  has_kids_for Switch, [:x_get_tree_switch_kids]
  has_kids_for EmsFolder, [:x_get_tree_folder_kids]

  private

  def tree_init_options(_)
    {
      :leaf     => "Switch",
      :open_all => true,
      :full_ids => true
    }
  end

  def set_locals_for_render
    locals = super
    locals.merge!(:id_prefix => 'nt_', :autoload => true)
  end

  def root_options
    [t = _("All Distributed Switches"), t]
  end

  def x_get_tree_roots(count_only, _options)
    objects = Rbac.filtered(ManageIQ::Providers::Vmware::InfraManager.order("lower(name)"))
    objects.each do |item|
      item[:load_children => true]
    end
    count_only_or_objects(count_only, objects)
  end

  def x_get_tree_provider_kids(object, count_only)
    count_only_or_objects(count_only,
                          Rbac.filtered(EmsCluster.where(:ems_id => object[:id])),
                          "name")
  end

  def x_get_tree_cluster_kids(object, count_only)
    hosts = object.hosts
    switch_ids = hosts.collect { |host| host.switches.pluck(:id) }
    count_only_or_objects(count_only, Rbac.filtered(Switch, :where_clause => ["shared = true and id in(?)", switch_ids.flatten.uniq]))
  end

  def x_get_tree_host_kids(object, count_only)
    count_only_or_objects(count_only,
                          Rbac.filtered(object.switches.where(:shared =>'true')).sort,
                          "name")
  end

  def x_get_tree_switch_kids(object, count_only)
    objects = count_only_or_objects(count_only,
                                    object.lans.sort,
                                    "name")
    objects.each do |item|
      item[:load_children => true]
      item[:cfmeNoClick => true]
    end
  end
end
